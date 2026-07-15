import {
  initSync,
  signUp,
  signIn,
  signOutUser,
  resetPassword,
  resendConfirmation,
  updatePassword,
  isPasswordRecoveryLink,
  fetchCloudBudget,
  pushCloudBudget,
  friendlyAuthError,
  deleteOwnBudgetAndSignOut,
  fetchMySharedMembership,
  fetchSharedBudget,
  pushSharedBudget,
  createSharedBudget,
  createBudgetInvite,
  acceptBudgetInvite,
  listBudgetMembers,
  leaveSharedBudget,
  subscribeSharedBudget,
} from "./sync.js";
import {
  AUTH_PASSWORD_HINT,
  assertImportFileSize,
  clearAuthFailures,
  escapeHtml,
  getAuthLockout,
  safeLog,
  sanitizeBudgetState,
  validateAccountName,
  validateAmount,
  validateCategoryName,
  validateDate,
  validateDescription,
  validateEmail,
  validatePassword,
  validateTransactionType,
} from "./security.js";

const STORAGE_KEY = "budget-studio-state-v7";
const SELECTED_MONTH_KEY = "budget-studio-selected-month";
const THEME_KEY = "budget-studio-theme";
const PROFILES_KEY = "budget-studio-profiles";
const CLOUD_DIRTY_KEY = "budget-studio-cloud-dirty";
const QUICK_ADD_PREFS_KEY = "budget-studio-quick-add-prefs";
const PENDING_JOIN_KEY = "budget-studio-pending-join";

// Shared/couples budget session state (declared before init() — TDZ).
// sharedBudget = { id, role } while the signed-in user is in a shared budget.
let sharedBudget = null;
let unsubscribeSharedChannel = null;
let lastSharedAppliedAt = 0;

// Quick-add sheet state (declared before init() runs at module eval — TDZ).
const quickAdd = { open: false, type: "Expense", amount: "" };

// Header theme-toggle icons (Feather, MIT). Declared before init() — TDZ.
const ICON_MOON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" /></svg>';
const ICON_SUN =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="5" /><line x1="12" y1="1" x2="12" y2="3" /><line x1="12" y1="21" x2="12" y2="23" /><line x1="4.22" y1="4.22" x2="5.64" y2="5.64" /><line x1="18.36" y1="18.36" x2="19.78" y2="19.78" /><line x1="1" y1="12" x2="3" y2="12" /><line x1="21" y1="12" x2="23" y2="12" /><line x1="4.22" y1="19.78" x2="5.64" y2="18.36" /><line x1="18.36" y1="5.64" x2="19.78" y2="4.22" /></svg>';

const groupChartColors = {
  Needs: ["#2563eb", "#0ea5e9", "#0284c7", "#0891b2"],
  Wants: ["#7c3aed", "#9333ea", "#c026d3", "#db2777"],
  Savings: ["#16a34a", "#059669", "#0d9488", "#15803d"],
};

const accounts = ["Checking", "Credit Card", "Savings", "Cash", "Investment", "Venmo", "Other"];

const payFrequencies = {
  weekly: {
    name: "Weekly",
    blurb: "Every 7 days",
    intervalDays: 7,
    monthlyMultiplier: 52 / 12,
  },
  biweekly: {
    name: "Biweekly",
    blurb: "Every 2 weeks",
    intervalDays: 14,
    monthlyMultiplier: 26 / 12,
  },
  semimonthly: {
    name: "Twice a month",
    blurb: "Usually 1st and 15th",
    intervalDays: null,
    monthlyMultiplier: 2,
  },
  monthly: {
    name: "Monthly",
    blurb: "Once per month",
    intervalDays: null,
    monthlyMultiplier: 1,
  },
};

const defaultCategories = [
  { name: "Salary", type: "Income", group: "Income", budget: 0 },
  { name: "Side Income", type: "Income", group: "Income", budget: 0 },
  { name: "Interest", type: "Income", group: "Income", budget: 0 },
  { name: "Refund", type: "Income", group: "Income", budget: 0 },
  { name: "Housing", type: "Expense", group: "Needs", budget: 1800 },
  { name: "Utilities", type: "Expense", group: "Needs", budget: 250 },
  { name: "Cell Phone", type: "Expense", group: "Needs", budget: 90 },
  { name: "Groceries", type: "Expense", group: "Needs", budget: 650 },
  { name: "Transportation", type: "Expense", group: "Needs", budget: 400 },
  { name: "Insurance", type: "Expense", group: "Needs", budget: 250 },
  { name: "Healthcare", type: "Expense", group: "Needs", budget: 200 },
  { name: "Debt Payments", type: "Expense", group: "Needs", budget: 300 },
  { name: "Dining Out", type: "Expense", group: "Wants", budget: 350 },
  { name: "Subscriptions", type: "Expense", group: "Wants", budget: 100 },
  { name: "Shopping", type: "Expense", group: "Wants", budget: 300 },
  { name: "Entertainment", type: "Expense", group: "Wants", budget: 200 },
  { name: "Travel", type: "Expense", group: "Wants", budget: 250 },
  { name: "Personal Care", type: "Expense", group: "Wants", budget: 150 },
  { name: "Education", type: "Expense", group: "Wants", budget: 100 },
  { name: "Savings/Investing", type: "Expense", group: "Savings", budget: 500 },
  { name: "Emergency Fund", type: "Expense", group: "Savings", budget: 300 },
];

// Shared formatters (declared before init() runs at module eval — TDZ):
// Intl.NumberFormat construction is expensive and these run hundreds of times per render.
const MONEY_WHOLE_FORMAT = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
  maximumFractionDigits: 0,
});
const MONEY_CENTS_FORMAT = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
  maximumFractionDigits: 2,
});
const MONEY_COMPACT_FORMAT = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
  notation: "compact",
  maximumFractionDigits: 1,
});
const PERCENT_FORMAT = new Intl.NumberFormat("en-US", { style: "percent", maximumFractionDigits: 0 });

const defaultTransactions = [
  transaction("2026-07-01", "Income", "Salary", "Paycheck", "Checking", 4200),
  transaction("2026-07-01", "Expense", "Housing", "Rent", "Checking", 1800),
  transaction("2026-07-02", "Expense", "Groceries", "Weekly groceries", "Credit Card", 128.47),
  transaction("2026-07-03", "Expense", "Utilities", "Electric bill", "Checking", 210),
  transaction("2026-07-04", "Expense", "Dining Out", "Dinner", "Credit Card", 64.2),
  transaction("2026-07-05", "Expense", "Cell Phone", "Mobile phone bill", "Checking", 92.45),
  transaction("2026-07-05", "Expense", "Transportation", "Gas", "Credit Card", 45.5),
  transaction("2026-07-06", "Expense", "Subscriptions", "Streaming", "Credit Card", 39.99),
  transaction("2026-07-07", "Income", "Side Income", "Freelance project", "Checking", 350),
  transaction("2026-07-07", "Expense", "Shopping", "Household items", "Credit Card", 120.25),
  transaction("2026-07-08", "Expense", "Emergency Fund", "Savings transfer", "Savings", 300),
];

const budgetPresets = {
  single: {
    name: "Single person",
    blurb: "Balanced everyday budget with room for savings and fun.",
    targetRate: 0.9,
    recommended: [
      "Housing",
      "Utilities",
      "Cell Phone",
      "Groceries",
      "Transportation",
      "Insurance",
      "Healthcare",
      "Dining Out",
      "Subscriptions",
      "Shopping",
      "Entertainment",
      "Savings/Investing",
      "Emergency Fund",
    ],
    weights: {
      Housing: 34,
      Utilities: 5,
      "Cell Phone": 2,
      Groceries: 12,
      Transportation: 7,
      Insurance: 5,
      Healthcare: 4,
      "Debt Payments": 5,
      "Dining Out": 5,
      Subscriptions: 2,
      Shopping: 5,
      Entertainment: 3,
      Travel: 3,
      "Personal Care": 2,
      Education: 1,
      "Savings/Investing": 8,
      "Emergency Fund": 6,
    },
  },
  couple: {
    name: "Couple",
    blurb: "Shared bills, higher groceries, and steadier savings.",
    targetRate: 0.88,
    recommended: [
      "Housing",
      "Utilities",
      "Cell Phone",
      "Groceries",
      "Transportation",
      "Insurance",
      "Healthcare",
      "Dining Out",
      "Subscriptions",
      "Shopping",
      "Travel",
      "Savings/Investing",
      "Emergency Fund",
    ],
    weights: {
      Housing: 32,
      Utilities: 6,
      "Cell Phone": 2,
      Groceries: 15,
      Transportation: 8,
      Insurance: 6,
      Healthcare: 4,
      "Debt Payments": 5,
      "Dining Out": 5,
      Subscriptions: 2,
      Shopping: 5,
      Entertainment: 3,
      Travel: 5,
      "Personal Care": 2,
      Education: 1,
      "Savings/Investing": 9,
      "Emergency Fund": 5,
    },
  },
  family: {
    name: "Family",
    blurb: "More practical categories for household spending.",
    targetRate: 0.92,
    recommended: [
      "Housing",
      "Utilities",
      "Cell Phone",
      "Groceries",
      "Transportation",
      "Insurance",
      "Healthcare",
      "Debt Payments",
      "Dining Out",
      "Subscriptions",
      "Shopping",
      "Entertainment",
      "Education",
      "Savings/Investing",
      "Emergency Fund",
    ],
    weights: {
      Housing: 32,
      Utilities: 6,
      "Cell Phone": 2,
      Groceries: 18,
      Transportation: 9,
      Insurance: 7,
      Healthcare: 6,
      "Debt Payments": 5,
      "Dining Out": 4,
      Subscriptions: 2,
      Shopping: 5,
      Entertainment: 3,
      Travel: 3,
      "Personal Care": 2,
      Education: 4,
      "Savings/Investing": 7,
      "Emergency Fund": 5,
    },
  },
  student: {
    name: "Student",
    blurb: "Lean setup with school, food, transit, and essentials.",
    targetRate: 0.82,
    recommended: [
      "Housing",
      "Utilities",
      "Cell Phone",
      "Groceries",
      "Transportation",
      "Healthcare",
      "Dining Out",
      "Subscriptions",
      "Education",
      "Emergency Fund",
    ],
    weights: {
      Housing: 34,
      Utilities: 5,
      "Cell Phone": 3,
      Groceries: 16,
      Transportation: 7,
      Healthcare: 4,
      "Dining Out": 5,
      Subscriptions: 3,
      Shopping: 3,
      Entertainment: 3,
      Education: 10,
      "Savings/Investing": 4,
      "Emergency Fund": 6,
    },
  },
  debt: {
    name: "Debt payoff",
    blurb: "Prioritizes debt and emergency savings without hiding essentials.",
    targetRate: 0.95,
    recommended: [
      "Housing",
      "Utilities",
      "Cell Phone",
      "Groceries",
      "Transportation",
      "Insurance",
      "Healthcare",
      "Debt Payments",
      "Dining Out",
      "Subscriptions",
      "Emergency Fund",
    ],
    weights: {
      Housing: 30,
      Utilities: 5,
      "Cell Phone": 2,
      Groceries: 12,
      Transportation: 7,
      Insurance: 5,
      Healthcare: 4,
      "Debt Payments": 18,
      "Dining Out": 3,
      Subscriptions: 2,
      Shopping: 2,
      Entertainment: 2,
      Travel: 1,
      "Personal Care": 2,
      "Savings/Investing": 2,
      "Emergency Fund": 5,
    },
  },
  irregular: {
    name: "Irregular income",
    blurb: "Keeps budgets conservative and builds a stronger buffer.",
    targetRate: 0.78,
    recommended: [
      "Housing",
      "Utilities",
      "Cell Phone",
      "Groceries",
      "Transportation",
      "Insurance",
      "Healthcare",
      "Debt Payments",
      "Dining Out",
      "Subscriptions",
      "Emergency Fund",
      "Savings/Investing",
    ],
    weights: {
      Housing: 33,
      Utilities: 5,
      "Cell Phone": 2,
      Groceries: 13,
      Transportation: 7,
      Insurance: 5,
      Healthcare: 4,
      "Debt Payments": 5,
      "Dining Out": 3,
      Subscriptions: 2,
      Shopping: 3,
      Entertainment: 2,
      Travel: 2,
      "Personal Care": 2,
      "Savings/Investing": 5,
      "Emergency Fund": 9,
    },
  },
};

const expenseCategoryNames = defaultCategories
  .filter((category) => category.type === "Expense")
  .map((category) => category.name);

const elements = {
  monthInput: document.querySelector("#monthInput"),
  monthLabel: document.querySelector("#monthLabel"),
  prevMonthBtn: document.querySelector("#prevMonthBtn"),
  nextMonthBtn: document.querySelector("#nextMonthBtn"),
  incomeMetric: document.querySelector("#incomeMetric"),
  spentMetric: document.querySelector("#spentMetric"),
  budgetRing: document.querySelector("#budgetRing"),
  budgetUsedMetric: document.querySelector("#budgetUsedMetric"),
  ringSubtext: document.querySelector("#ringSubtext"),
  payPeriodBadge: document.querySelector("#payPeriodBadge"),
  payPeriodRange: document.querySelector("#payPeriodRange"),
  paycheckIncomeMetric: document.querySelector("#paycheckIncomeMetric"),
  paycheckSpentMetric: document.querySelector("#paycheckSpentMetric"),
  paycheckLeftMetric: document.querySelector("#paycheckLeftMetric"),
  paycheckLeftRange: document.querySelector("#paycheckLeftRange"),
  paycheckBreakdown: document.querySelector("#paycheckBreakdown"),
  payScheduleForm: document.querySelector("#payScheduleForm"),
  payScheduleDialog: document.querySelector("#payScheduleDialog"),
  editPayScheduleBtn: document.querySelector("#editPayScheduleBtn"),
  closePayScheduleBtn: document.querySelector("#closePayScheduleBtn"),
  settingsPayFrequencyGrid: document.querySelector("#settingsPayFrequencyGrid"),
  settingsPayAmountInput: document.querySelector("#settingsPayAmountInput"),
  settingsNextPayDateInput: document.querySelector("#settingsNextPayDateInput"),
  settingsPayScheduleSubtitle: document.querySelector("#settingsPayScheduleSubtitle"),
  savePayScheduleBtn: document.querySelector("#savePayScheduleBtn"),
  budgetsDialog: document.querySelector("#budgetsDialog"),
  editBudgetsBtn: document.querySelector("#editBudgetsBtn"),
  closeBudgetsBtn: document.querySelector("#closeBudgetsBtn"),
  settingsBudgetsSubtitle: document.querySelector("#settingsBudgetsSubtitle"),
  netMetric: document.querySelector("#netMetric"),
  savingsMetric: document.querySelector("#savingsMetric"),
  topCategoryBadge: document.querySelector("#topCategoryBadge"),
  categoryChart: document.querySelector("#categoryChart"),
  trendChart: document.querySelector("#trendChart"),
  categoryProgress: document.querySelector("#categoryProgress"),
  transactionForm: document.querySelector("#transactionForm"),
  dateInput: document.querySelector("#dateInput"),
  typeInput: document.querySelector("#typeInput"),
  categoryInput: document.querySelector("#categoryInput"),
  accountInput: document.querySelector("#accountInput"),
  descriptionInput: document.querySelector("#descriptionInput"),
  amountInput: document.querySelector("#amountInput"),
  formMessage: document.querySelector("#formMessage"),
  clearFormBtn: document.querySelector("#clearFormBtn"),
  quickAddSheet: document.querySelector("#quickAddSheet"),
  qaTypeToggle: document.querySelector("#qaTypeToggle"),
  qaCloseBtn: document.querySelector("#qaCloseBtn"),
  qaAmountDisplay: document.querySelector("#qaAmountDisplay"),
  qaKeypad: document.querySelector("#qaKeypad"),
  qaCategoryInput: document.querySelector("#qaCategoryInput"),
  qaAccountInput: document.querySelector("#qaAccountInput"),
  qaDateInput: document.querySelector("#qaDateInput"),
  qaDescriptionInput: document.querySelector("#qaDescriptionInput"),
  qaSubmitBtn: document.querySelector("#qaSubmitBtn"),
  qaMessage: document.querySelector("#qaMessage"),
  upcomingPanel: document.querySelector("#upcomingPanel"),
  upcomingList: document.querySelector("#upcomingList"),
  recurringList: document.querySelector("#recurringList"),
  recurringForm: document.querySelector("#recurringForm"),
  recTypeInput: document.querySelector("#recTypeInput"),
  recCategoryInput: document.querySelector("#recCategoryInput"),
  recAccountInput: document.querySelector("#recAccountInput"),
  recDayInput: document.querySelector("#recDayInput"),
  recDescriptionInput: document.querySelector("#recDescriptionInput"),
  recAmountInput: document.querySelector("#recAmountInput"),
  recurringMessage: document.querySelector("#recurringMessage"),
  sharedPanel: document.querySelector("#sharedPanel"),
  sharedSolo: document.querySelector("#sharedSolo"),
  sharedActive: document.querySelector("#sharedActive"),
  sharedMembersLine: document.querySelector("#sharedMembersLine"),
  shareBudgetBtn: document.querySelector("#shareBudgetBtn"),
  inviteRow: document.querySelector("#inviteRow"),
  inviteLinkInput: document.querySelector("#inviteLinkInput"),
  copyInviteBtn: document.querySelector("#copyInviteBtn"),
  newInviteBtn: document.querySelector("#newInviteBtn"),
  leaveSharedBtn: document.querySelector("#leaveSharedBtn"),
  sharedMessage: document.querySelector("#sharedMessage"),
  transactionsBody: document.querySelector("#transactionsBody"),
  searchInput: document.querySelector("#searchInput"),
  typeFilter: document.querySelector("#typeFilter"),
  budgetEditor: document.querySelector("#budgetEditor"),
  categoryBuilderForm: document.querySelector("#categoryBuilderForm"),
  categoryBuilderNameInput: document.querySelector("#categoryBuilderNameInput"),
  categoryBuilderGroupInput: document.querySelector("#categoryBuilderGroupInput"),
  categoryBuilderBudgetInput: document.querySelector("#categoryBuilderBudgetInput"),
  categoryBuilderAddBtn: document.querySelector("#categoryBuilderAddBtn"),
  categoryBuilderMessage: document.querySelector("#categoryBuilderMessage"),
  resetBtn: document.querySelector("#resetBtn"),
  openSetupBtn: document.querySelector("#openSetupBtn"),
  closeSettingsBtn: document.querySelector("#closeSettingsBtn"),
  homeView: document.querySelector("#homeView"),
  settingsView: document.querySelector("#settingsView"),
  bottomDock: document.querySelector("#bottomDock"),
  overviewTab: document.querySelector("#overviewTab"),
  activityTab: document.querySelector("#activityTab"),
  goalsTab: document.querySelector("#goalsTab"),
  settingsTab: document.querySelector("#settingsTab"),
  activityCashflowChart: document.querySelector("#activityCashflowChart"),
  activityIncomeMetric: document.querySelector("#activityIncomeMetric"),
  activitySpentMetric: document.querySelector("#activitySpentMetric"),
  activityNetMetric: document.querySelector("#activityNetMetric"),
  activityNetChip: document.querySelector("#activityNetChip"),
  goalsList: document.querySelector("#goalsList"),
  goalForm: document.querySelector("#goalForm"),
  goalEditIdInput: document.querySelector("#goalEditIdInput"),
  goalNameInput: document.querySelector("#goalNameInput"),
  goalTargetInput: document.querySelector("#goalTargetInput"),
  goalCurrentInput: document.querySelector("#goalCurrentInput"),
  goalSubmitBtn: document.querySelector("#goalSubmitBtn"),
  goalCancelEditBtn: document.querySelector("#goalCancelEditBtn"),
  goalFormMessage: document.querySelector("#goalFormMessage"),
  tabBar: document.querySelector("#tabBar"),
  addTransactionBtn: document.querySelector("#addTransactionBtn"),
  exportCsvBtn: document.querySelector("#exportCsvBtn"),
  importCsvInput: document.querySelector("#importCsvInput"),
  exportJsonBtn: document.querySelector("#exportJsonBtn"),
  importJsonInput: document.querySelector("#importJsonInput"),
  deleteAccountBtn: document.querySelector("#deleteAccountBtn"),
  privacyLink: document.querySelector("#privacyLink"),
  termsLink: document.querySelector("#termsLink"),
  authLegal: document.querySelector("#authLegal"),
  setupWizard: document.querySelector("#setupWizard"),
  wizardStepLabel: document.querySelector("#wizardStepLabel"),
  wizardProgressFill: document.querySelector("#wizardProgressFill"),
  closeWizardBtn: document.querySelector("#closeWizardBtn"),
  startWizardBtn: document.querySelector("#startWizardBtn"),
  demoModeBtn: document.querySelector("#demoModeBtn"),
  wizardBackBtn: document.querySelector("#wizardBackBtn"),
  wizardNextBtn: document.querySelector("#wizardNextBtn"),
  presetGrid: document.querySelector("#presetGrid"),
  payFrequencyGrid: document.querySelector("#payFrequencyGrid"),
  wizardPayAmountInput: document.querySelector("#wizardPayAmountInput"),
  wizardNextPayDateInput: document.querySelector("#wizardNextPayDateInput"),
  wizardMonthlyEstimate: document.querySelector("#wizardMonthlyEstimate"),
  categoryChecklist: document.querySelector("#categoryChecklist"),
  customCategoryNameInput: document.querySelector("#customCategoryNameInput"),
  customCategoryGroupInput: document.querySelector("#customCategoryGroupInput"),
  addCustomCategoryBtn: document.querySelector("#addCustomCategoryBtn"),
  customCategoryMessage: document.querySelector("#customCategoryMessage"),
  wizardBudgetReview: document.querySelector("#wizardBudgetReview"),
  reviewTotalBudget: document.querySelector("#reviewTotalBudget"),
  reviewLeftover: document.querySelector("#reviewLeftover"),
  themeToggleBtn: document.querySelector("#themeToggleBtn"),
  toastStack: document.querySelector("#toastStack"),
  editDialog: document.querySelector("#editDialog"),
  editForm: document.querySelector("#editForm"),
  closeEditBtn: document.querySelector("#closeEditBtn"),
  editDateInput: document.querySelector("#editDateInput"),
  editTypeInput: document.querySelector("#editTypeInput"),
  editCategoryInput: document.querySelector("#editCategoryInput"),
  editAccountInput: document.querySelector("#editAccountInput"),
  editDescriptionInput: document.querySelector("#editDescriptionInput"),
  editAmountInput: document.querySelector("#editAmountInput"),
  appTitle: document.querySelector("#appTitle"),
  appSubtitle: document.querySelector("#appSubtitle"),
  authGate: document.querySelector("#authGate"),
  authTitle: document.querySelector("#authTitle"),
  authCopy: document.querySelector("#authCopy"),
  authForm: document.querySelector("#authForm"),
  authNameLabel: document.querySelector("#authNameLabel"),
  authNameInput: document.querySelector("#authNameInput"),
  authEmailLabel: document.querySelector("#authEmailLabel"),
  authEmailInput: document.querySelector("#authEmailInput"),
  authPasswordLabel: document.querySelector("#authPasswordLabel"),
  authPasswordLabelText: document.querySelector("#authPasswordLabelText"),
  authPasswordInput: document.querySelector("#authPasswordInput"),
  authPasswordHelp: document.querySelector("#authPasswordHelp"),
  authSubmitBtn: document.querySelector("#authSubmitBtn"),
  authResendBtn: document.querySelector("#authResendBtn"),
  authConfirmedBtn: document.querySelector("#authConfirmedBtn"),
  authModeToggleBtn: document.querySelector("#authModeToggleBtn"),
  authForgotBtn: document.querySelector("#authForgotBtn"),
  authMessage: document.querySelector("#authMessage"),
  signOutBtn: document.querySelector("#signOutBtn"),
};

let activeTab = "overview";

let currentUser = null;
let localOnlyMode = false;
let authMode = "signin"; // signin | signup | recovery
let cloudSaveTimer = null;
/** Avoid toast spam while typing category budgets or during rapid edits. */
let didNotifySyncFailure = false;
let state = createEmptyState();
let wizard = createWizardDraft(false);
let editingTransactionId = null;

init();

function init() {
  initTheme();
  capturePendingJoinToken();
  setSelectedMonth(localStorage.getItem(SELECTED_MONTH_KEY) || currentMonthKey());
  elements.dateInput.value = defaultDateForMonth(elements.monthInput.value);
  elements.accountInput.innerHTML = accounts.map((account) => `<option>${escapeHtml(account)}</option>`).join("");
  elements.editAccountInput.innerHTML = accounts.map((account) => `<option>${escapeHtml(account)}</option>`).join("");
  if (elements.recAccountInput) {
    elements.recAccountInput.innerHTML = accounts.map((account) => `<option>${escapeHtml(account)}</option>`).join("");
  }
  populateCategorySelect();
  populateRecurringCategorySelect();
  attachEvents();
  installGlobalKeyboard();
  render();
  initSync(handleUserChanged).catch(() => handleUserChanged(null, { unavailable: true }));
  window.addEventListener("online", flushDirtyCloudSave);
}

async function handleUserChanged(user, info) {
  if (info?.unavailable) {
    // No cloud configured: behave like the previous local-only app.
    // Never call cloud APIs in this mode — sync client is unavailable / refused.
    localOnlyMode = true;
    currentUser = { uid: "local", displayName: legacyProfileName() || "" };
    state = loadState();
    populateCategorySelect();
    renderIdentityUI();
    render();
    if (!state.setupComplete) openWizard(false);
    postDueRecurring();
    return;
  }

  localOnlyMode = false;
  currentUser = user;
  if (!user) {
    teardownShared();
    state = createEmptyState();
    renderIdentityUI();
    render();
    openAuthGate();
    return;
  }

  // Password-recovery links sign the user in temporarily so they can set a new password.
  // Do NOT load or sync budget data until the password is updated (limits session abuse window).
  if (isPasswordRecoveryLink() || authMode === "recovery") {
    currentUser = user;
    state = createEmptyState();
    openAuthGate();
    setAuthMode("recovery");
    elements.authPasswordInput.focus();
    return;
  }

  closeAuthGate();
  state = loadState();
  populateCategorySelect();
  renderIdentityUI();
  render();

  // Shared budgets: redeem a pending invite, then check membership. When in a
  // shared budget, its row replaces the personal cloud flow entirely.
  await resolveSharedMembership();
  if (sharedBudget) {
    await loadSharedState();
    renderSharedPanel();
    if (!state.setupComplete) openWizard(false);
    postDueRecurring();
    return;
  }
  renderSharedPanel();

  try {
    const cloud = await fetchCloudBudget(user.uid);
    const local = readCachePayload(user.uid);
    const cloudAt = cloud?.updatedAt || 0;
    const localAt = local?.updatedAt || 0;
    if (cloud && (!local || cloudAt > localAt)) {
      const before = (cloud.state?.transactions || []).length;
      state = normalizeState(cloud.state);
      const stripped = before !== state.transactions.length;
      writeCachePayload(user.uid, {
        state,
        updatedAt: stripped ? Date.now() : cloud.updatedAt || Date.now(),
        name: user.displayName || "",
      });
      if (stripped) {
        // Push cleanup so invented paychecks don't come back from cloud.
        saveState();
      }
      populateCategorySelect();
      render();
    } else if (local && (!cloud || localAt >= cloudAt)) {
      // Keep newer local (e.g. setup finished before cloud push) and sync up.
      const before = (local.state?.transactions || []).length;
      state = normalizeState(local.state);
      const stripped = before !== state.transactions.length;
      populateCategorySelect();
      render();
      if (stripped) {
        // Persist + push cleaned ledger so invented paychecks don't reappear from cloud.
        saveState();
      } else if (!cloud || localAt > cloudAt) {
        await pushCloudBudget(user.uid, {
          state,
          updatedAt: local.updatedAt || Date.now(),
          name: user.displayName || "",
        });
      }
    } else if (!cloud && !local) {
      const legacy = readLegacyState();
      if (legacy) {
        state = normalizeState(legacy);
        saveState();
        populateCategorySelect();
        render();
      }
    }
    flushDirtyCloudSave();
  } catch {
    localStorage.setItem(CLOUD_DIRTY_KEY, "1");
    if (!didNotifySyncFailure) {
      didNotifySyncFailure = true;
      showToast("Working offline — changes save on this device.", "error");
    }
  }

  if (!state.setupComplete) {
    openWizard(false);
  }

  // After local/cloud state has settled, post any recurring items now due.
  postDueRecurring();
}

// ---------------------------------------------------------------------------
// Shared/couples budgets (docs/SHARED_BUDGETS.md). V1: one shared budget per
// user; shared row is last-write-wins, kept live via Supabase Realtime.
// ---------------------------------------------------------------------------

function teardownShared() {
  if (unsubscribeSharedChannel) {
    try {
      unsubscribeSharedChannel();
    } catch {
      /* channel already gone */
    }
  }
  unsubscribeSharedChannel = null;
  sharedBudget = null;
  lastSharedAppliedAt = 0;
}

/** Stash ?join=<token> from the URL so it survives the sign-in/confirm dance. */
function capturePendingJoinToken() {
  try {
    const params = new URLSearchParams(window.location.search);
    const token = params.get("join");
    if (!token) return;
    sessionStorage.setItem(PENDING_JOIN_KEY, token);
    params.delete("join");
    const query = params.toString();
    history.replaceState(
      null,
      "",
      `${window.location.pathname}${query ? `?${query}` : ""}${window.location.hash}`,
    );
  } catch {
    /* sessionStorage blocked — join just won't survive a redirect */
  }
}

async function resolveSharedMembership() {
  teardownShared();
  const pending = sessionStorage.getItem(PENDING_JOIN_KEY);
  if (pending) {
    try {
      const budgetId = await acceptBudgetInvite(pending);
      sharedBudget = { id: budgetId, role: "member" };
      showToast("You joined the shared budget!");
    } catch (error) {
      const raw = String(error?.message || "");
      showToast(
        /expired/i.test(raw)
          ? "That invite link expired — ask for a new one."
          : /used/i.test(raw)
            ? "That invite link was already used."
            : "That invite didn't work — ask for a fresh link.",
        "error",
      );
    }
    sessionStorage.removeItem(PENDING_JOIN_KEY);
  }
  if (!sharedBudget) {
    try {
      sharedBudget = await fetchMySharedMembership();
    } catch {
      sharedBudget = null; // offline — personal flow covers this session
    }
  }
  if (sharedBudget) startSharedSubscription();
}

async function loadSharedState() {
  try {
    const remote = await fetchSharedBudget(sharedBudget.id);
    const local = readCachePayload(currentUser.uid);
    if (remote && (!local || remote.updatedAt >= (local.updatedAt || 0))) {
      lastSharedAppliedAt = remote.updatedAt;
      state = normalizeState(remote.state);
      writeCachePayload(currentUser.uid, { state, updatedAt: remote.updatedAt, name: remote.name });
    } else if (local) {
      // This device edited offline more recently — push it up (last write wins).
      state = normalizeState(local.state);
      lastSharedAppliedAt = local.updatedAt || Date.now();
      await pushSharedBudget(sharedBudget.id, local);
    }
    populateCategorySelect();
    render();
    flushDirtyCloudSave();
  } catch {
    localStorage.setItem(CLOUD_DIRTY_KEY, "1");
    if (!didNotifySyncFailure) {
      didNotifySyncFailure = true;
      showToast("Working offline — changes save on this device.", "error");
    }
  }
}

function startSharedSubscription() {
  if (!sharedBudget || unsubscribeSharedChannel) return;
  try {
    unsubscribeSharedChannel = subscribeSharedBudget(sharedBudget.id, applyRemoteSharedChange);
  } catch {
    /* realtime unavailable — edits still land on reload */
  }
}

async function applyRemoteSharedChange() {
  if (!sharedBudget) return;
  try {
    const remote = await fetchSharedBudget(sharedBudget.id);
    // Skip our own write echoes and stale events.
    if (!remote || remote.updatedAt <= lastSharedAppliedAt) return;
    lastSharedAppliedAt = remote.updatedAt;
    state = normalizeState(remote.state);
    writeCachePayload(currentUser.uid, { state, updatedAt: remote.updatedAt, name: remote.name });
    populateCategorySelect();
    render();
    if (activeTab === "settings") renderRecurringList();
    showToast("Budget updated by your partner.");
  } catch {
    /* transient fetch failure — next event or reload catches up */
  }
}

function setSharedMessage(message, isError = false) {
  if (!elements.sharedMessage) return;
  elements.sharedMessage.textContent = message;
  elements.sharedMessage.style.color = isError ? "var(--red)" : "var(--muted)";
}

function renderSharedPanel() {
  if (!elements.sharedPanel) return;
  const eligible = !localOnlyMode && currentUser && currentUser.uid !== "local";
  elements.sharedPanel.hidden = !eligible;
  if (!eligible) return;
  elements.sharedSolo.hidden = Boolean(sharedBudget);
  elements.sharedActive.hidden = !sharedBudget;
  if (!sharedBudget) {
    elements.inviteRow.hidden = true;
    return;
  }
  elements.newInviteBtn.hidden = sharedBudget.role !== "owner";
  elements.sharedMembersLine.textContent =
    sharedBudget.role === "owner" ? "You own this shared budget." : "You're in a shared budget.";
  listBudgetMembers(sharedBudget.id)
    .then((members) => {
      if (!sharedBudget) return;
      const count =
        members.length === 1
          ? "Just you so far — send the invite link!"
          : `${members.length} people share this budget.`;
      elements.sharedMembersLine.textContent = `${count} You're the ${sharedBudget.role}.`;
    })
    .catch(() => {});
}

async function mintInviteLink() {
  const token = await createBudgetInvite(sharedBudget.id);
  elements.inviteLinkInput.value = `${window.location.origin}${window.location.pathname}?join=${token}`;
  elements.inviteRow.hidden = false;
}

async function shareBudgetFlow() {
  if (sharedBudget || !currentUser) return;
  elements.shareBudgetBtn.disabled = true;
  setSharedMessage("Setting up your shared budget…");
  try {
    const first = (currentUser.displayName || "").trim().split(/\s+/)[0];
    const name = first ? `${first}'s shared budget` : "Shared budget";
    const budgetId = await createSharedBudget(state, name);
    sharedBudget = { id: budgetId, role: "owner" };
    lastSharedAppliedAt = Date.now();
    writeCachePayload(currentUser.uid, { state, updatedAt: lastSharedAppliedAt, name });
    startSharedSubscription();
    await mintInviteLink();
    setSharedMessage("Done — send your partner the link below. It works once and expires in 7 days.");
    renderSharedPanel();
  } catch (error) {
    setSharedMessage(friendlyAuthError(error) || "Couldn't create the shared budget. Try again.", true);
  } finally {
    elements.shareBudgetBtn.disabled = false;
  }
}

/**
 * Transactions you keep when leaving a shared budget: your own entries and any
 * untagged history stay; a partner's tagged entries drop out. Author stamps are
 * shed since the result is a personal budget again (which stays untagged).
 */
function keepOnLeave(transactions, uid) {
  return transactions
    .filter((tx) => !tx.addedBy || tx.addedBy === uid)
    .map(({ addedBy, addedByName, ...tx }) => tx);
}

async function leaveSharedFlow() {
  if (!sharedBudget || !currentUser) return;
  const sure = window.confirm(
    "Leave the shared budget? You'll keep your own copy — your entries stay, your partner's transactions drop out, and your partner keeps the shared budget.",
  );
  if (!sure) return;
  try {
    const budgetId = sharedBudget.id;
    // Snapshot the shared budget as it stands, minus the partner's entries.
    const kept = { ...state, transactions: keepOnLeave(state.transactions, currentUser.uid) };
    await leaveSharedBudget(budgetId);
    teardownShared();
    // Personal mode now: this snapshot becomes and overwrites the personal
    // budget. saveState() caches it immediately and syncs to the personal row.
    state = normalizeState(kept);
    populateCategorySelect();
    saveState();
    render();
    renderSharedPanel();
    setSharedMessage("");
    showToast("Left the shared budget — your copy is saved.");
  } catch (error) {
    setSharedMessage(friendlyAuthError(error) || "Couldn't leave right now. Try again.", true);
  }
}

function attachEvents() {
  elements.monthInput.addEventListener("change", () => {
    setSelectedMonth(elements.monthInput.value);
    elements.dateInput.value = defaultDateForMonth(elements.monthInput.value);
    render();
  });

  elements.prevMonthBtn?.addEventListener("click", () => shiftMonth(-1));
  elements.nextMonthBtn?.addEventListener("click", () => shiftMonth(1));
  elements.monthLabel?.addEventListener("click", () => {
    try {
      elements.monthInput.showPicker();
    } catch {
      // showPicker needs a user gesture + support; fall back to focusing the input.
      elements.monthInput.focus();
      elements.monthInput.click();
    }
  });

  elements.typeInput.addEventListener("change", populateCategorySelect);
  elements.searchInput.addEventListener("input", renderTransactions);
  elements.typeFilter.addEventListener("change", renderTransactions);

  elements.clearFormBtn.addEventListener("click", () => {
    elements.transactionForm.reset();
    elements.typeInput.value = "Expense";
    elements.dateInput.value = defaultDateForMonth(elements.monthInput.value);
    populateCategorySelect();
    setMessage("");
  });

  elements.transactionForm.addEventListener("submit", (event) => {
    event.preventDefault();
    const dateCheck = validateDate(elements.dateInput.value);
    const amountCheck = validateAmount(elements.amountInput.value);
    const typeCheck = validateTransactionType(elements.typeInput.value);
    const categoryCheck = validateCategoryName(elements.categoryInput.value);
    const descriptionCheck = validateDescription(
      elements.descriptionInput.value.trim() || elements.categoryInput.value,
    );
    if (!dateCheck.ok || !amountCheck.ok || !typeCheck.ok || !categoryCheck.ok || !descriptionCheck.ok) {
      setMessage(
        dateCheck.message || amountCheck.message || typeCheck.message || categoryCheck.message || descriptionCheck.message,
        true,
      );
      return;
    }

    const item = stampAuthor(
      transaction(
        dateCheck.value,
        typeCheck.value,
        categoryCheck.value,
        descriptionCheck.value,
        elements.accountInput.value,
        amountCheck.value,
      ),
    );

    state.transactions.push(item);
    saveState();
    elements.descriptionInput.value = "";
    elements.amountInput.value = "";
    setMessage("Transaction added.");
    render();
  });

  elements.transactionsBody.addEventListener("click", (event) => {
    const emptyAction = event.target.closest("[data-empty-action]");
    if (emptyAction) {
      if (emptyAction.dataset.emptyAction === "clear-filters") {
        elements.searchInput.value = "";
        elements.typeFilter.value = "All";
        renderTransactions();
      } else {
        openQuickAdd();
      }
      return;
    }

    const deleteButton = event.target.closest("[data-delete-id]");
    if (deleteButton) {
      const id = deleteButton.dataset.deleteId;
      const index = state.transactions.findIndex((item) => item.id === id);
      if (index === -1) return;
      const [removed] = state.transactions.splice(index, 1);
      saveState();
      render();
      showToast("Transaction deleted.", "success", {
        actionLabel: "Undo",
        duration: 5000,
        onAction: () => {
          state.transactions.splice(Math.min(index, state.transactions.length), 0, removed);
          saveState();
          render();
          showToast("Transaction restored.");
        },
      });
      return;
    }

    const editButton = event.target.closest("[data-edit-id]");
    const row = event.target.closest("[data-transaction-id]");
    const id = editButton?.dataset.editId || row?.dataset.transactionId;
    if (id) openEditDialog(id);
  });

  elements.budgetEditor?.addEventListener("change", (event) => {
    const input = event.target.closest("[data-budget-category]");
    if (!input) return;
    const category = state.categories.find((item) => item.name === input.dataset.budgetCategory);
    if (!category) return;
    category.budget = Math.max(0, Number(input.value) || 0);
    saveState();
    updateBudgetsSummary();
    renderDashboard();
  });
  elements.budgetEditor?.addEventListener("click", (event) => {
    const button = event.target.closest("[data-delete-category]");
    if (!button) return;
    deleteCategoryFromBudgets(button.dataset.deleteCategory);
  });
  elements.categoryBuilderForm.addEventListener("submit", (event) => {
    event.preventDefault();
    addCategoryFromBudgetPanel();
  });
  elements.categoryBuilderAddBtn.addEventListener("click", (event) => {
    event.preventDefault();
    addCategoryFromBudgetPanel();
  });

  elements.goalForm?.addEventListener("submit", (event) => {
    event.preventDefault();
    saveGoalFromForm();
  });
  elements.goalCancelEditBtn?.addEventListener("click", () => resetGoalForm());
  elements.goalsList?.addEventListener("click", (event) => {
    const editId = event.target.closest("[data-edit-goal]")?.dataset.editGoal;
    if (editId) {
      startEditGoal(editId);
      return;
    }
    const deleteId = event.target.closest("[data-delete-goal]")?.dataset.deleteGoal;
    if (deleteId) deleteGoal(deleteId);
  });

  elements.recurringForm?.addEventListener("submit", (event) => {
    event.preventDefault();
    addRecurringFromForm();
  });
  elements.recTypeInput?.addEventListener("change", populateRecurringCategorySelect);
  elements.recurringList?.addEventListener("click", (event) => {
    const button = event.target.closest("[data-recurring-id]");
    if (!button) return;
    const index = (state.recurring || []).findIndex((item) => item.id === button.dataset.recurringId);
    if (index === -1) return;
    const [removed] = state.recurring.splice(index, 1);
    saveState();
    renderRecurringList();
    showToast(`${removed.description} removed.`, "success", {
      actionLabel: "Undo",
      duration: 5000,
      onAction: () => {
        state.recurring.splice(Math.min(index, state.recurring.length), 0, removed);
        saveState();
        renderRecurringList();
        showToast("Recurring item restored.");
      },
    });
  });

  elements.shareBudgetBtn?.addEventListener("click", shareBudgetFlow);
  elements.newInviteBtn?.addEventListener("click", async () => {
    try {
      await mintInviteLink();
      setSharedMessage("Fresh link ready — single use, expires in 7 days.");
    } catch (error) {
      setSharedMessage(friendlyAuthError(error) || "Couldn't create an invite link. Try again.", true);
    }
  });
  elements.copyInviteBtn?.addEventListener("click", async () => {
    try {
      await navigator.clipboard.writeText(elements.inviteLinkInput.value);
      setSharedMessage("Link copied — text it to your partner.");
    } catch {
      elements.inviteLinkInput.select();
      setSharedMessage("Copy blocked — the link is selected, press ⌘C / Ctrl+C.");
    }
  });
  elements.leaveSharedBtn?.addEventListener("click", leaveSharedFlow);

  elements.resetBtn.addEventListener("click", () => openWizard(true));
  elements.openSetupBtn.addEventListener("click", () => switchTab("settings"));
  elements.closeSettingsBtn.addEventListener("click", () => switchTab("overview"));
  elements.payScheduleForm?.addEventListener("submit", (event) => {
    event.preventDefault();
    savePayScheduleFromSettings();
  });
  elements.editPayScheduleBtn?.addEventListener("click", openPayScheduleDialog);
  elements.closePayScheduleBtn?.addEventListener("click", closePayScheduleDialog);
  elements.payScheduleDialog?.addEventListener("click", (event) => {
    if (event.target === elements.payScheduleDialog) closePayScheduleDialog();
  });
  elements.editBudgetsBtn?.addEventListener("click", openBudgetsDialog);
  elements.closeBudgetsBtn?.addEventListener("click", closeBudgetsDialog);
  elements.budgetsDialog?.addEventListener("click", (event) => {
    if (event.target === elements.budgetsDialog) closeBudgetsDialog();
  });
  elements.settingsPayFrequencyGrid?.addEventListener("click", (event) => {
    const button = event.target.closest("[data-frequency-id]");
    if (!button || !elements.settingsPayFrequencyGrid) return;
    elements.settingsPayFrequencyGrid.querySelectorAll("[data-frequency-id]").forEach((node) => {
      node.classList.toggle("selected", node === button);
    });
  });
  elements.tabBar?.querySelectorAll("[data-tab]").forEach((button) => {
    button.addEventListener("click", (event) => {
      event.preventDefault();
      const tab = button.getAttribute("data-tab") || button.dataset.tab;
      if (tab) switchTab(tab);
    });
  });
  elements.addTransactionBtn?.addEventListener("click", openQuickAdd);

  elements.qaCloseBtn?.addEventListener("click", closeQuickAdd);
  elements.quickAddSheet?.addEventListener("click", (event) => {
    if (event.target === elements.quickAddSheet) closeQuickAdd();
  });
  elements.qaTypeToggle?.addEventListener("click", (event) => {
    const button = event.target.closest("[data-qa-type]");
    if (button) setQuickAddType(button.dataset.qaType);
  });
  elements.qaKeypad?.addEventListener("click", (event) => {
    const button = event.target.closest("[data-qa-key]");
    if (button) pressQuickAddKey(button.dataset.qaKey);
  });
  elements.qaSubmitBtn?.addEventListener("click", submitQuickAdd);
  elements.qaDescriptionInput?.addEventListener("keydown", (event) => {
    if (event.key === "Enter") submitQuickAdd();
  });
  document.addEventListener("keydown", (event) => {
    if (!quickAdd.open) return;
    if (event.key === "Escape") {
      closeQuickAdd();
      return;
    }
    // Physical-keyboard amount entry, unless the user is typing in a field.
    const tag = event.target.tagName;
    if (tag === "INPUT" || tag === "SELECT" || tag === "TEXTAREA") return;
    if (/^[0-9.]$/.test(event.key)) {
      pressQuickAddKey(event.key);
      event.preventDefault();
    } else if (event.key === "Backspace") {
      pressQuickAddKey("back");
      event.preventDefault();
    } else if (event.key === "Enter" && tag !== "BUTTON") {
      // Focused buttons already submit/press via their native click.
      submitQuickAdd();
    }
  });
  elements.closeWizardBtn.addEventListener("click", closeWizard);
  elements.startWizardBtn.addEventListener("click", () => {
    wizard.step = 1;
    renderWizard();
  });
  elements.demoModeBtn.addEventListener("click", () => {
    state = createDemoState();
    saveState();
    populateCategorySelect();
    hideWizard();
    render();
    setMessage("Demo mode loaded. Use Setup when you are ready to make it yours.");
  });
  elements.wizardBackBtn.addEventListener("click", () => {
    wizard.step = Math.max(0, wizard.step - 1);
    renderWizard();
  });
  elements.wizardNextBtn.addEventListener("click", advanceWizard);
  elements.presetGrid.addEventListener("click", (event) => {
    const button = event.target.closest("[data-preset-id]");
    if (!button) return;
    wizard.presetId = button.dataset.presetId;
    wizard.selectedCategories = new Set([
      ...budgetPresets[wizard.presetId].recommended,
      ...wizard.customCategories.map((category) => category.name),
    ]);
    wizard.customBudgets = {};
    renderWizard();
  });
  elements.payFrequencyGrid.addEventListener("click", (event) => {
    const button = event.target.closest("[data-frequency-id]");
    if (!button) return;
    wizard.payFrequency = button.dataset.frequencyId;
    wizard.customBudgets = {};
    renderWizard();
  });
  elements.wizardPayAmountInput.addEventListener("input", () => {
    wizard.payAmount = Math.max(0, Number(elements.wizardPayAmountInput.value) || 0);
    wizard.income = monthlyIncomeFromPay(wizard.payAmount, wizard.payFrequency);
    wizard.customBudgets = {};
    renderWizardSummary();
  });
  elements.wizardNextPayDateInput.addEventListener("change", () => {
    wizard.nextPayDate = elements.wizardNextPayDateInput.value || todayString();
    renderWizardSummary();
  });
  elements.categoryChecklist.addEventListener("change", (event) => {
    const input = event.target.closest("[data-category-choice]");
    if (!input) return;
    if (input.checked) {
      wizard.selectedCategories.add(input.value);
    } else {
      wizard.selectedCategories.delete(input.value);
    }
    wizard.customBudgets = {};
    renderCategoryChecklist();
  });
  elements.addCustomCategoryBtn.addEventListener("click", addCustomWizardCategory);
  elements.customCategoryNameInput.addEventListener("keydown", (event) => {
    if (event.key !== "Enter") return;
    event.preventDefault();
    addCustomWizardCategory();
  });
  elements.wizardBudgetReview.addEventListener("input", (event) => {
    const input = event.target.closest("[data-review-budget]");
    if (!input) return;
    wizard.customBudgets[input.dataset.reviewBudget] = Math.max(0, Number(input.value) || 0);
    renderWizardSummary();
  });

  elements.exportCsvBtn.addEventListener("click", exportCsv);
  elements.importCsvInput?.addEventListener("change", importCsv);
  elements.exportJsonBtn.addEventListener("click", exportJson);
  elements.importJsonInput.addEventListener("change", importJson);
  elements.deleteAccountBtn?.addEventListener("click", handleDeleteAccount);

  elements.authForm.addEventListener("submit", handleAuthSubmit);
  elements.authModeToggleBtn.addEventListener("click", () => {
    setAuthMode(authMode === "signin" ? "signup" : "signin");
  });
  elements.authForgotBtn.addEventListener("click", handleForgotPassword);
  elements.authResendBtn.addEventListener("click", handleResendConfirmation);
  elements.authConfirmedBtn.addEventListener("click", () => attemptConfirmedSignIn(false));
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible" && authMode === "confirm") attemptConfirmedSignIn(true);
  });
  elements.signOutBtn.addEventListener("click", async () => {
    await handleSignOut();
  });

  elements.themeToggleBtn.addEventListener("click", toggleTheme);
  elements.closeEditBtn.addEventListener("click", closeEditDialog);
  elements.editForm.addEventListener("submit", saveEditTransaction);
  elements.editTypeInput.addEventListener("change", () => populateEditCategorySelect(elements.editTypeInput.value));
  elements.editDialog.addEventListener("click", (event) => {
    if (event.target === elements.editDialog) closeEditDialog();
  });
}

function switchTab(tab) {
  // Re-query panels each switch so a stale elements cache cannot drop Goals.
  const panels = {
    overview: document.querySelector("#overviewTab"),
    activity: document.querySelector("#activityTab"),
    goals: document.querySelector("#goalsTab"),
    settings: document.querySelector("#settingsTab"),
  };
  elements.overviewTab = panels.overview;
  elements.activityTab = panels.activity;
  elements.goalsTab = panels.goals;
  elements.settingsTab = panels.settings;

  const requested = String(tab || "").trim();
  activeTab = panels[requested] ? requested : "overview";

  Object.entries(panels).forEach(([name, panel]) => {
    if (!panel) return;
    const show = name === activeTab;
    panel.toggleAttribute("hidden", !show);
    panel.classList.toggle("is-active-panel", show);
  });
  elements.tabBar?.querySelectorAll("[data-tab]").forEach((button) => {
    const selected = button.dataset.tab === activeTab;
    button.classList.toggle("is-active", selected);
    if (selected) button.setAttribute("aria-current", "page");
    else button.removeAttribute("aria-current");
  });
  if (activeTab === "settings") {
    updatePayScheduleSummary();
    updateBudgetsSummary();
    populateRecurringCategorySelect();
    renderRecurringList();
    renderSharedPanel();
  } else {
    render();
  }
  renderIdentityUI();
  window.scrollTo({ top: 0, behavior: "smooth" });
}

function updatePayScheduleSummary() {
  const profile = normalizeSetupProfile(state.setupProfile);
  const month = elements.monthInput?.value || currentMonthKey();
  const paySummary = getPayPeriodSummary(month);
  const frequencyName = payFrequencies[profile.payFrequency]?.name || "Biweekly";
  const amountPart = profile.payAmount > 0 ? `${money(profile.payAmount)} · ${frequencyName}` : frequencyName;
  const subtitle = paySummary.rangeLabel ? `${paySummary.rangeLabel} · ${amountPart}` : amountPart;
  if (elements.settingsPayScheduleSubtitle) {
    elements.settingsPayScheduleSubtitle.textContent = subtitle;
  }
}

function populatePayScheduleForm() {
  if (!elements.settingsPayFrequencyGrid) return;
  const profile = normalizeSetupProfile(state.setupProfile);
  elements.settingsPayFrequencyGrid.innerHTML = Object.entries(payFrequencies)
    .map(([id, frequency]) => {
      const selected = profile.payFrequency === id ? "selected" : "";
      return `
        <button class="pay-frequency-card ${selected}" type="button" data-frequency-id="${id}">
          <strong>${escapeHtml(frequency.name)}</strong>
          <span>${escapeHtml(frequency.blurb)}</span>
        </button>
      `;
    })
    .join("");
  if (elements.settingsPayAmountInput) {
    elements.settingsPayAmountInput.value = profile.payAmount > 0 ? String(profile.payAmount) : "";
  }
  if (elements.settingsNextPayDateInput) {
    elements.settingsNextPayDateInput.value = profile.nextPayDate || todayString();
  }
  updatePayScheduleSummary();
}

function openPayScheduleDialog() {
  populatePayScheduleForm();
  if (elements.payScheduleDialog) elements.payScheduleDialog.hidden = false;
  document.body.classList.add("wizard-open");
}

function closePayScheduleDialog() {
  if (elements.payScheduleDialog) elements.payScheduleDialog.hidden = true;
  syncOverlayBodyClass();
}

function updateBudgetsSummary() {
  const expenseCategories = state.categories.filter((category) => category.type === "Expense");
  const count = expenseCategories.length;
  const total = expenseCategories.reduce((sum, category) => sum + (Number(category.budget) || 0), 0);
  let subtitle = "No categories yet";
  if (count === 1) subtitle = `1 category · ${money(total)}/mo`;
  else if (count > 1) subtitle = `${count} categories · ${money(total)}/mo`;
  if (elements.settingsBudgetsSubtitle) {
    elements.settingsBudgetsSubtitle.textContent = subtitle;
  }
}

function openBudgetsDialog() {
  renderBudgetEditor();
  if (elements.budgetsDialog) elements.budgetsDialog.hidden = false;
  document.body.classList.add("wizard-open");
}

function closeBudgetsDialog() {
  if (elements.budgetsDialog) elements.budgetsDialog.hidden = true;
  syncOverlayBodyClass();
  updateBudgetsSummary();
}

function syncOverlayBodyClass() {
  const overlayOpen =
    (elements.setupWizard && !elements.setupWizard.hidden) ||
    (elements.editDialog && !elements.editDialog.hidden) ||
    (elements.payScheduleDialog && !elements.payScheduleDialog.hidden) ||
    (elements.budgetsDialog && !elements.budgetsDialog.hidden);
  document.body.classList.toggle("wizard-open", overlayOpen);
}

function savePayScheduleFromSettings() {
  const selected = elements.settingsPayFrequencyGrid?.querySelector("[data-frequency-id].selected");
  const payFrequency = selected?.dataset.frequencyId || state.setupProfile?.payFrequency || "biweekly";
  const payAmount = Math.max(0, Number(elements.settingsPayAmountInput?.value) || 0);
  const nextPayDate = elements.settingsNextPayDateInput?.value || todayString();
  const existing = normalizeSetupProfile(state.setupProfile);
  state.setupProfile = {
    ...existing,
    payAmount,
    payFrequency,
    nextPayDate,
    income: monthlyIncomeFromPay(payAmount, payFrequency),
    demo: false,
    completedAt: existing.completedAt || new Date().toISOString(),
  };
  state.setupComplete = true;
  saveState();
  closePayScheduleDialog();
  updatePayScheduleSummary();
  render();
  showToast("Pay schedule updated.");
}

function openSettingsView() {
  switchTab("settings");
}

function closeSettingsView() {
  switchTab("overview");
}

function openWizard(useCurrentState) {
  wizard = createWizardDraft(useCurrentState);
  elements.setupWizard.hidden = false;
  document.body.classList.add("wizard-open");
  renderWizard();
  focusWizardStep();
}

function closeWizard() {
  if (!state.setupComplete) {
    finishWizard();
    return;
  }
  hideWizard();
}

function hideWizard() {
  elements.setupWizard.hidden = true;
  document.body.classList.remove("wizard-open");
}

function advanceWizard() {
  if (wizard.step === 0) {
    wizard.step = 1;
  } else if (wizard.step < 4) {
    wizard.step += 1;
  } else {
    finishWizard();
    return;
  }
  renderWizard();
}

function finishWizard() {
  const finalCategories = createCategoriesFromWizard();
  // Never invent paycheck transactions — users add real income themselves.
  // First-time setup starts with an empty ledger; re-running setup keeps existing rows
  // but still strips any leftover invented "Biweekly paycheck" rows from older builds.
  const existingTransactions = stripAutoGeneratedPaychecks(
    state.setupComplete ? state.transactions : [],
  );

  state = {
    categories: finalCategories,
    transactions: existingTransactions,
    recurring: Array.isArray(state.recurring) ? state.recurring : [],
    savingsGoals: Array.isArray(state.savingsGoals) ? state.savingsGoals : [],
    setupComplete: true,
    setupProfile: {
      presetId: wizard.presetId,
      income: wizard.income,
      payAmount: wizard.payAmount,
      payFrequency: wizard.payFrequency,
      nextPayDate: wizard.nextPayDate,
      completedAt: new Date().toISOString(),
    },
  };

  saveState();
  populateCategorySelect();
  hideWizard();
  render();
  setMessage(
    state.transactions.length
      ? "Budget updated. Your transactions were left as-is."
      : "Your budget is set up. Add income and expenses when you're ready — nothing was invented for you.",
  );
}

function renderWizard() {
  wizard.income = monthlyIncomeFromPay(wizard.payAmount, wizard.payFrequency);
  document.querySelectorAll(".wizard-step").forEach((step) => {
    step.hidden = Number(step.dataset.step) !== wizard.step;
  });

  const labels = ["Welcome", "Step 1 of 4", "Step 2 of 4", "Step 3 of 4", "Step 4 of 4"];
  elements.wizardStepLabel.textContent = labels[wizard.step];
  elements.wizardProgressFill.style.width = `${Math.max(8, (wizard.step / 4) * 100)}%`;
  elements.wizardBackBtn.hidden = wizard.step === 0;
  elements.wizardNextBtn.hidden = wizard.step === 0;
  elements.wizardNextBtn.textContent = wizard.step === 4 ? "Finish setup" : "Continue";
  elements.closeWizardBtn.textContent = state.setupComplete ? "Close" : "Skip";

  renderPresetGrid();
  renderPayFrequencyGrid();
  renderCategoryChecklist();
  renderWizardBudgetReview();
  renderWizardSummary();
  syncWizardControls();
  focusWizardStep();
}

function renderPresetGrid() {
  elements.presetGrid.innerHTML = Object.entries(budgetPresets)
    .map(([id, preset]) => {
      const selected = wizard.presetId === id ? "selected" : "";
      return `
        <button class="preset-card ${selected}" type="button" data-preset-id="${id}">
          <strong>${escapeHtml(preset.name)}</strong>
          <span>${escapeHtml(preset.blurb)}</span>
        </button>
      `;
    })
    .join("");
}

function renderPayFrequencyGrid() {
  elements.payFrequencyGrid.innerHTML = Object.entries(payFrequencies)
    .map(([id, frequency]) => {
      const selected = wizard.payFrequency === id ? "selected" : "";
      return `
        <button class="pay-frequency-card ${selected}" type="button" data-frequency-id="${id}">
          <strong>${escapeHtml(frequency.name)}</strong>
          <span>${escapeHtml(frequency.blurb)}</span>
        </button>
      `;
    })
    .join("");
}

function renderCategoryChecklist() {
  elements.categoryChecklist.innerHTML = getWizardExpenseCategories()
    .map((category) => {
      const checked = wizard.selectedCategories.has(category.name);
      const customClass = category.custom ? "custom" : "";
      const categoryMeta = category.custom ? `Custom - ${category.group}` : category.group;
      return `
        <label class="category-toggle ${checked ? "selected" : ""} ${customClass}">
          <input
            type="checkbox"
            value="${escapeHtml(category.name)}"
            data-category-choice
            ${checked ? "checked" : ""}
          />
          <strong>${escapeHtml(category.name)}</strong>
          <span>${escapeHtml(categoryMeta)}</span>
        </label>
      `;
    })
    .join("");
}

function addCustomWizardCategory() {
  const nameCheck = validateCategoryName(elements.customCategoryNameInput.value);
  if (!nameCheck.ok) {
    setCustomCategoryMessage(nameCheck.message, true);
    return;
  }
  const name = nameCheck.value;

  if (categoryExists(getWizardExpenseCategories(), name)) {
    setCustomCategoryMessage(`${name} already exists. Select it above.`, true);
    return;
  }

  const group = normalizeCategoryGroup(elements.customCategoryGroupInput.value);
  wizard.customCategories.push({
    name,
    type: "Expense",
    group,
    budget: 0,
    custom: true,
  });
  wizard.selectedCategories.add(name);
  wizard.customBudgets[name] = 0;
  elements.customCategoryNameInput.value = "";
  setCustomCategoryMessage(`${name} added and selected.`);
  renderCategoryChecklist();
  renderWizardBudgetReview();
  renderWizardSummary();
}

function setCustomCategoryMessage(message, isError = false) {
  elements.customCategoryMessage.textContent = message;
  elements.customCategoryMessage.style.color = isError ? "var(--red)" : "var(--muted)";
}

function renderWizardBudgetReview() {
  const rows = getWizardBudgetRows();
  elements.wizardBudgetReview.innerHTML = rows
    .map(
      (row) => `
        <label class="review-budget-row">
          <span>
            <strong>${escapeHtml(row.name)}</strong>
            <small>${escapeHtml(row.group)}</small>
          </span>
          <input
            type="number"
            min="0"
            step="10"
            value="${row.budget}"
            data-review-budget="${escapeHtml(row.name)}"
            aria-label="${escapeHtml(row.name)} suggested monthly budget"
          />
        </label>
      `,
    )
    .join("");
}

function renderWizardSummary() {
  wizard.income = monthlyIncomeFromPay(wizard.payAmount, wizard.payFrequency);
  const rows = getWizardBudgetRows();
  const total = sum(rows.map((row) => row.budget));
  const leftover = wizard.income - total;
  elements.reviewTotalBudget.textContent = `${money(total)} planned`;
  elements.reviewLeftover.textContent =
    leftover >= 0 ? `${money(leftover)} unassigned buffer` : `${money(Math.abs(leftover))} over income`;
  elements.reviewLeftover.className = "";
  elements.wizardMonthlyEstimate.textContent = `${money(wizard.income)} estimated monthly take-home`;
  elements.wizardNextBtn.disabled = wizard.step === 3 && wizard.selectedCategories.size === 0;
}

function syncWizardControls() {
  elements.wizardPayAmountInput.value = wizard.payAmount > 0 ? String(wizard.payAmount) : "";
  elements.wizardNextPayDateInput.value = wizard.nextPayDate;
}

function getWizardBudgetRows() {
  const preset = budgetPresets[wizard.presetId];
  const selected = [...wizard.selectedCategories];
  const templates = getWizardExpenseCategories();
  const weightTotal = sum(selected.map((name) => wizardCategoryWeight(name, preset, templates))) || 1;
  const budgetPool = wizard.income * preset.targetRate;

  return selected
    .map((name) => {
      const template = templates.find((category) => category.name === name) || {
        name,
        type: "Expense",
        group: "Needs",
      };
      const suggested = template.custom
        ? template.budget || 0
        : roundToNearest((budgetPool * wizardCategoryWeight(name, preset, templates)) / weightTotal, 10);
      return {
        ...template,
        budget: wizard.customBudgets[name] ?? suggested,
      };
    })
    .sort((a, b) => groupRank(a.group) - groupRank(b.group) || a.name.localeCompare(b.name));
}

function getWizardExpenseCategories() {
  const seen = new Set();
  return [
    ...defaultCategories.filter((category) => category.type === "Expense"),
    ...(wizard.customCategories || []),
  ].filter((category) => {
    const key = categoryKey(category.name);
    if (!key || seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function wizardCategoryWeight(name, preset, templates) {
  const template = templates.find((category) => category.name === name);
  if (template?.custom) return 0;
  return preset.weights[name] || 1;
}

function createCategoriesFromWizard() {
  const incomeCategories = defaultCategories.filter((category) => category.type === "Income");
  const expenseCategories = getWizardBudgetRows().map((row) => ({
    name: row.name,
    type: "Expense",
    group: row.group,
    budget: row.budget,
  }));
  return [...structuredClone(incomeCategories), ...expenseCategories];
}

function createWizardDraft(useCurrentState) {
  const profile = state?.setupProfile || {};
  const payFrequency = profile.payFrequency || "biweekly";
  // Only reuse a paycheck amount the user already saved — never invent $4500→$2075 defaults.
  const payAmount = Number(profile.payAmount) > 0
    ? profile.payAmount
    : 0;
  const nextPayDate = profile.nextPayDate || nextDefaultPayDate(payFrequency);
  const currentExpenseCategories = state?.categories?.filter((category) => category.type === "Expense") || [];
  const defaultExpenseKeys = new Set(expenseCategoryNames.map(categoryKey));
  const customCategories = useCurrentState
    ? currentExpenseCategories
        .filter((category) => !defaultExpenseKeys.has(categoryKey(category.name)))
        .map((category) => ({
          name: category.name,
          type: "Expense",
          group: normalizeCategoryGroup(category.group),
          budget: Math.max(0, Number(category.budget) || 0),
          custom: true,
        }))
    : [];
  const selectedCategories = useCurrentState && currentExpenseCategories.length
    ? currentExpenseCategories.map((category) => category.name)
    : budgetPresets.single.recommended;
  const customBudgets = useCurrentState
    ? Object.fromEntries(currentExpenseCategories.map((category) => [category.name, category.budget]))
    : {};

  return {
    step: useCurrentState ? 1 : 0,
    presetId: profile.presetId || "single",
    payFrequency,
    payAmount: Math.max(0, Number(payAmount) || 0),
    nextPayDate,
    income: monthlyIncomeFromPay(payAmount, payFrequency),
    selectedCategories: new Set(selectedCategories),
    customCategories,
    customBudgets,
  };
}

function render() {
  // Month label lives in the shared header; keep it fresh on every render.
  syncMonthLabel(elements.monthInput.value);
  // Only the visible tab is rendered; switchTab() re-renders on switch.
  if (activeTab === "activity") {
    renderActivityCashflow();
    renderActivityCharts();
    renderTransactions();
  } else if (activeTab === "goals") renderGoals();
  else if (activeTab === "overview") renderDashboard();
  else if (activeTab === "settings") updateBudgetsSummary();
}

function renderDashboard() {
  const month = elements.monthInput.value;
  syncMonthLabel(month);
  const summary = getMonthSummary(month);
  const usedPercent = summary.totalBudget ? summary.expenses / summary.totalBudget : 0;
  const net = summary.income - summary.expenses;

  elements.incomeMetric.textContent = money(summary.income);
  elements.spentMetric.textContent = money(summary.expenses);
  elements.budgetUsedMetric.textContent = percent(usedPercent);
  elements.budgetRing.style.setProperty("--used", `${Math.min(100, Math.max(0, usedPercent * 100))}%`);
  elements.budgetRing.classList.toggle("over", usedPercent > 1);
  elements.ringSubtext.textContent = statusCopy(usedPercent);
  elements.netMetric.textContent = `${money(net)} left from income`;
  elements.netMetric.className = `money-chip ${net < 0 ? "is-negative" : "is-positive"}`;

  renderProgress(summary.categoryRows);
  renderPaycheckView(month);
  renderUpcoming();
  renderIdentityUI();
}

function renderActivityCharts() {
  const month = elements.monthInput.value;
  const summary = getMonthSummary(month);
  const net = summary.income - summary.expenses;
  const savingsRate = summary.income ? net / summary.income : 0;
  const topCategory = summary.categoryRows.find((row) => row.spent > 0);

  if (elements.savingsMetric) {
    elements.savingsMetric.textContent = `${percent(savingsRate)} saved`;
    elements.savingsMetric.className = `money-chip ${savingsRate < 0 ? "is-negative" : ""}`;
  }
  if (elements.topCategoryBadge) {
    elements.topCategoryBadge.textContent = topCategory
      ? `${topCategory.name}: ${money(topCategory.spent)}`
      : "No spending yet";
  }

  renderBarChart(summary.categoryRows);
  renderTrendChart(month);
}

function renderPaycheckView(month) {
  const paySummary = getPayPeriodSummary(month);
  elements.payPeriodBadge.textContent = paySummary.label;
  elements.payPeriodRange.textContent = paySummary.rangeLabel;
  elements.paycheckIncomeMetric.textContent = money(paySummary.income);
  elements.paycheckSpentMetric.textContent = money(paySummary.expenses);
  elements.paycheckLeftMetric.textContent = money(paySummary.left);
  if (elements.paycheckLeftRange) {
    elements.paycheckLeftRange.textContent = paySummary.rangeLabel;
  }
  updatePayScheduleSummary();

  const rows = paySummary.categoryRows.filter((row) => row.spent > 0).slice(0, 5);
  if (!rows.length) {
    elements.paycheckBreakdown.innerHTML = `<div class="empty-state">No expenses logged in this pay period yet.</div>`;
    return;
  }

  const max = Math.max(...rows.map((row) => row.spent));
  elements.paycheckBreakdown.innerHTML = rows
    .map((row) => {
      const width = Math.max(6, (row.spent / max) * 100);
      return `
        <div class="paycheck-breakdown-row">
          <strong>${escapeHtml(row.name)}</strong>
          <div class="progress-track">
            <div class="progress-fill" style="width:${width}%"></div>
          </div>
          <span>${money(row.spent)}</span>
        </div>
      `;
    })
    .join("");
}

function renderProgress(rows) {
  // Dynamic: hide idle $0/$0; reappear when spent > 0 or budget > 0.
  const visible = rows.filter((row) => row.spent > 0 || row.budget > 0);
  if (!visible.length) {
    elements.categoryProgress.innerHTML = `<div class="empty-state">No budgeted or spent categories this month.</div>`;
    return;
  }
  elements.categoryProgress.innerHTML = visible
    .map((row) => {
      const used = row.budget ? row.spent / row.budget : 0;
      const width = Math.min(100, used * 100);
      const status = used > 1 ? "over" : used >= 0.85 ? "watch" : "good";
      return `
        <div class="progress-row">
          <div class="progress-label">
            <strong>${escapeHtml(row.name)}</strong>
            <small>${escapeHtml(row.group)}</small>
          </div>
          <div class="progress-track" aria-label="${escapeHtml(row.name)} budget progress">
            <div class="progress-fill ${status}" style="width:${width}%"></div>
          </div>
          <div class="progress-amount">${money(row.spent)} / ${money(row.budget)}</div>
        </div>
      `;
    })
    .join("");
}

function renderBarChart(rows) {
  if (!elements.categoryChart) return;
  const data = rows.filter((row) => row.spent > 0).slice(0, 8);
  if (!data.length) {
    elements.categoryChart.innerHTML = `<div class="empty-state">No spending logged for this month.</div>`;
    return;
  }

  const width = 760;
  const rowHeight = 30;
  const height = 48 + data.length * rowHeight;
  const labelWidth = 150;
  const barWidth = 470;
  const max = Math.max(...data.map((row) => row.spent));

  const rowsSvg = data
    .map((row, index) => {
      const y = 34 + index * rowHeight;
      const w = Math.max(8, (row.spent / max) * barWidth);
      const fill = chartColorForCategory(row, index);
      return `
        <text x="0" y="${y + 15}" class="svg-label">${escapeHtml(row.name)}</text>
        <rect x="${labelWidth}" y="${y}" width="${w}" height="18" rx="6" fill="${fill}"></rect>
        <text x="${labelWidth + w + 10}" y="${y + 14}" class="svg-value">${money(row.spent)}</text>
      `;
    })
    .join("");

  elements.categoryChart.innerHTML = `
    <svg class="chart-svg" viewBox="0 0 ${width} ${height}" role="img" aria-label="Spending by category">
      ${rowsSvg}
    </svg>
  `;
}

function renderTrendChart(selectedMonth) {
  if (!elements.trendChart) return;
  const months = monthRange(selectedMonth, 11);
  // One pass over all transactions instead of 12 full getMonthSummary() scans.
  const byMonth = new Map(months.map((month) => [month, { income: 0, expenses: 0 }]));
  for (const item of state.transactions) {
    const bucket = byMonth.get(monthKeyFromDate(item.date));
    if (!bucket) continue;
    if (item.type === "Income") bucket.income += item.amount;
    else if (item.type === "Expense") bucket.expenses += item.amount;
  }
  const points = months.map((month) => {
    const { income, expenses } = byMonth.get(month);
    return {
      month,
      label: shortMonth(month),
      income,
      expenses,
      net: income - expenses,
    };
  });

  const width = 820;
  const height = 260;
  const padding = { top: 18, right: 26, bottom: 42, left: 62 };
  const values = points.flatMap((point) => [point.income, point.expenses, point.net, 0]);
  const max = Math.max(...values, 100);
  const min = Math.min(...values, 0);
  const span = max - min || 1;
  const chartWidth = width - padding.left - padding.right;
  const chartHeight = height - padding.top - padding.bottom;

  const x = (index) => padding.left + (index / Math.max(1, points.length - 1)) * chartWidth;
  const y = (value) => padding.top + ((max - value) / span) * chartHeight;
  const pathFor = (key) => points.map((point, index) => `${index ? "L" : "M"} ${x(index)} ${y(point[key])}`).join(" ");
  const grid = [0, 0.25, 0.5, 0.75, 1]
    .map((ratio) => {
      const lineY = padding.top + ratio * chartHeight;
      const value = max - ratio * span;
      return `
        <line class="grid-line" x1="${padding.left}" x2="${width - padding.right}" y1="${lineY}" y2="${lineY}" />
        <text x="8" y="${lineY + 4}" class="axis">${compactMoney(value)}</text>
      `;
    })
    .join("");
  const labels = points
    .map((point, index) => `<text x="${x(index)}" y="${height - 14}" text-anchor="middle" class="axis">${point.label}</text>`)
    .join("");

  elements.trendChart.innerHTML = `
    <svg class="chart-svg" viewBox="0 0 ${width} ${height}" role="img" aria-label="Income, spending, and cash flow trend">
      ${grid}
      <line class="zero-line" x1="${padding.left}" x2="${width - padding.right}" y1="${y(0)}" y2="${y(0)}" />
      <path class="series-income" d="${pathFor("income")}" fill="none" stroke-width="3" stroke-linecap="round" />
      <path class="series-expense" d="${pathFor("expenses")}" fill="none" stroke-width="3" stroke-linecap="round" />
      <path class="series-net" d="${pathFor("net")}" fill="none" stroke-width="3" stroke-linecap="round" />
      ${labels}
      <circle class="dot-income" cx="610" cy="18" r="5"></circle><text x="620" y="22" class="legend">Income</text>
      <circle class="dot-expense" cx="690" cy="18" r="5"></circle><text x="700" y="22" class="legend">Spent</text>
      <circle class="dot-net" cx="760" cy="18" r="5"></circle><text x="770" y="22" class="legend">Net</text>
    </svg>
  `;
}

function renderTransactions() {
  const query = elements.searchInput.value.trim().toLowerCase();
  const type = elements.typeFilter.value;
  const selectedMonth = elements.monthInput.value;
  const rows = state.transactions
    .filter((item) => monthKeyFromDate(item.date) === selectedMonth)
    .filter((item) => type === "All" || item.type === type)
    .filter((item) => {
      if (!query) return true;
      return [item.date, item.type, item.category, item.description, item.account]
        .join(" ")
        .toLowerCase()
        .includes(query);
    })
    .sort((a, b) => b.date.localeCompare(a.date));

  if (!rows.length) {
    const filtersActive = Boolean(query) || type !== "All";
    const monthLabel = formatMonthLabel(selectedMonth);
    elements.transactionsBody.innerHTML = filtersActive
      ? `
      <tr>
        <td colspan="7" class="table-empty">
          <p>No transactions match your search or filter.</p>
          <button class="ghost-button" data-empty-action="clear-filters" type="button">Clear filters</button>
        </td>
      </tr>
    `
      : `
      <tr>
        <td colspan="7" class="table-empty">
          <p>Nothing logged in ${escapeHtml(monthLabel)} yet.</p>
          <button class="primary-button" data-empty-action="quick-add" type="button">Add your first transaction</button>
        </td>
      </tr>
    `;
    return;
  }

  elements.transactionsBody.innerHTML = rows
    .map(
      (item) => `
        <tr class="table-row-clickable" data-transaction-id="${escapeHtml(item.id)}">
          <td>${formatDate(item.date)}</td>
          <td><span class="type-pill ${item.type.toLowerCase()}">${escapeHtml(item.type)}</span></td>
          <td>${escapeHtml(item.category)}</td>
          <td>${escapeHtml(item.description)}${authorTag(item)}</td>
          <td>${escapeHtml(item.account)}</td>
          <td class="amount">${money(item.amount)}</td>
          <td class="action-cell">
            <button class="edit-button" data-edit-id="${escapeHtml(item.id)}" type="button">Edit</button>
            <button class="delete-button" data-delete-id="${escapeHtml(item.id)}" type="button">Delete</button>
          </td>
        </tr>
      `,
    )
    .join("");
}

function renderActivityCashflow() {
  const chart = document.querySelector("#activityCashflowChart");
  if (!chart) return;
  elements.activityCashflowChart = chart;
  const month = elements.monthInput.value;
  const summary = getMonthSummary(month);
  const net = summary.income - summary.expenses;
  const incomeEl = document.querySelector("#activityIncomeMetric");
  const spentEl = document.querySelector("#activitySpentMetric");
  const netEl = document.querySelector("#activityNetMetric");
  const chipEl = document.querySelector("#activityNetChip");
  if (incomeEl) incomeEl.textContent = money(summary.income);
  if (spentEl) spentEl.textContent = money(summary.expenses);
  if (netEl) {
    netEl.textContent = money(net);
    netEl.classList.toggle("is-negative", net < 0);
  }
  if (chipEl) {
    chipEl.textContent = `${money(net)} net`;
    chipEl.className = `money-chip ${net < 0 ? "is-negative" : "is-positive"}`;
  }

  if (!summary.income && !summary.expenses) {
    chart.innerHTML = `<div class="empty-state">No income or spending logged for this month yet.</div>`;
    return;
  }

  const max = Math.max(summary.income, summary.expenses, 1);
  const incomePct = Math.max(4, Math.round((summary.income / max) * 100));
  const spentPct = Math.max(4, Math.round((summary.expenses / max) * 100));

  // HTML/CSS bars — more reliable than SVG fills in iOS Safari / installed PWAs.
  chart.innerHTML = `
    <div class="cashflow-bars" role="img" aria-label="Income ${money(summary.income)}, spent ${money(summary.expenses)}">
      <div class="cashflow-bar-row">
        <span class="cashflow-bar-label">Income</span>
        <div class="cashflow-bar-track">
          <div class="cashflow-bar-fill is-income" style="width:${incomePct}%"></div>
        </div>
        <span class="cashflow-bar-value">${money(summary.income)}</span>
      </div>
      <div class="cashflow-bar-row">
        <span class="cashflow-bar-label">Spent</span>
        <div class="cashflow-bar-track">
          <div class="cashflow-bar-fill is-spent" style="width:${spentPct}%"></div>
        </div>
        <span class="cashflow-bar-value">${money(summary.expenses)}</span>
      </div>
    </div>
  `;
}

function renderGoals() {
  if (!elements.goalsList) return;
  if (!Array.isArray(state.savingsGoals)) state.savingsGoals = [];
  const goals = state.savingsGoals;
  if (!goals.length) {
    elements.goalsList.innerHTML = `<div class="empty-state">No savings goals yet. Add one below — emergency fund, vacation, whatever you're working toward.</div>`;
    return;
  }
  elements.goalsList.innerHTML = goals
    .map((goal) => {
      const progress = goal.target > 0 ? Math.min(1, goal.current / goal.target) : 0;
      const width = Math.round(progress * 100);
      const left = Math.max(0, goal.target - goal.current);
      const done = goal.current >= goal.target;
      return `
        <article class="goal-card ${done ? "is-complete" : ""}" data-goal-id="${escapeHtml(goal.id)}">
          <div class="goal-card-top">
            <div>
              <strong>${escapeHtml(goal.name)}</strong>
              <span>${money(goal.current)} of ${money(goal.target)}${done ? " · Done" : ` · ${money(left)} to go`}</span>
            </div>
            <div class="goal-card-actions">
              <button class="edit-button" type="button" data-edit-goal="${escapeHtml(goal.id)}">Edit</button>
              <button class="delete-button" type="button" data-delete-goal="${escapeHtml(goal.id)}">Delete</button>
            </div>
          </div>
          <div class="progress-track" aria-label="${escapeHtml(goal.name)} progress">
            <div class="progress-fill ${done ? "good" : progress >= 0.85 ? "watch" : "good"}" style="width:${width}%"></div>
          </div>
        </article>
      `;
    })
    .join("");
}

function resetGoalForm() {
  if (!elements.goalForm) return;
  elements.goalEditIdInput.value = "";
  elements.goalForm.reset();
  if (elements.goalCurrentInput) elements.goalCurrentInput.value = "0";
  if (elements.goalSubmitBtn) elements.goalSubmitBtn.textContent = "Add goal";
  if (elements.goalCancelEditBtn) elements.goalCancelEditBtn.hidden = true;
  setGoalFormMessage("");
}

function setGoalFormMessage(message, isError = false) {
  if (!elements.goalFormMessage) return;
  elements.goalFormMessage.textContent = message;
  elements.goalFormMessage.style.color = isError ? "var(--red)" : "var(--muted)";
}

function startEditGoal(id) {
  const goal = state.savingsGoals.find((item) => item.id === id);
  if (!goal) return;
  elements.goalEditIdInput.value = goal.id;
  elements.goalNameInput.value = goal.name;
  elements.goalTargetInput.value = String(goal.target);
  elements.goalCurrentInput.value = String(goal.current);
  elements.goalSubmitBtn.textContent = "Save goal";
  elements.goalCancelEditBtn.hidden = false;
  elements.goalNameInput.focus();
  setGoalFormMessage("Editing — update the numbers and save.");
}

function saveGoalFromForm() {
  const nameCheck = validateCategoryName(elements.goalNameInput.value);
  if (!nameCheck.ok) {
    setGoalFormMessage(nameCheck.message, true);
    return;
  }
  const target = Number(elements.goalTargetInput.value);
  if (!Number.isFinite(target) || target <= 0) {
    setGoalFormMessage("Enter a target greater than zero.", true);
    return;
  }
  let current = Number(elements.goalCurrentInput.value);
  if (!Number.isFinite(current) || current < 0) current = 0;
  current = Math.min(current, 1_000_000_000);
  const cappedTarget = Math.min(target, 1_000_000_000);
  if (!Array.isArray(state.savingsGoals)) state.savingsGoals = [];

  const editId = elements.goalEditIdInput.value;
  if (editId) {
    const goal = state.savingsGoals.find((item) => item.id === editId);
    if (!goal) {
      setGoalFormMessage("That goal was already removed.", true);
      resetGoalForm();
      return;
    }
    goal.name = nameCheck.value;
    goal.target = cappedTarget;
    goal.current = current;
    saveState();
    resetGoalForm();
    renderGoals();
    showToast("Goal updated.");
    return;
  }

  if (state.savingsGoals.length >= 50) {
    setGoalFormMessage("You can have up to 50 goals.", true);
    return;
  }
  state.savingsGoals.push({
    id: crypto.randomUUID ? crypto.randomUUID() : `goal-${Date.now()}`,
    name: nameCheck.value,
    target: cappedTarget,
    current,
  });
  saveState();
  resetGoalForm();
  renderGoals();
  showToast("Goal added.");
}

function deleteGoal(id) {
  if (!Array.isArray(state.savingsGoals)) return;
  const index = state.savingsGoals.findIndex((item) => item.id === id);
  if (index === -1) return;
  const [removed] = state.savingsGoals.splice(index, 1);
  if (elements.goalEditIdInput?.value === id) resetGoalForm();
  saveState();
  renderGoals();
  showToast("Goal deleted.", "success", {
    actionLabel: "Undo",
    duration: 5000,
    onAction: () => {
      state.savingsGoals.splice(Math.min(index, state.savingsGoals.length), 0, removed);
      saveState();
      renderGoals();
      showToast("Goal restored.");
    },
  });
}

function renderBudgetEditor() {
  if (!elements.budgetEditor) return;
  const expenseCategories = state.categories.filter((category) => category.type === "Expense");
  if (!expenseCategories.length) {
    elements.budgetEditor.innerHTML = `<div class="empty-state">No expense categories yet. Add one below.</div>`;
    return;
  }
  elements.budgetEditor.innerHTML = expenseCategories
    .map(
      (category) => `
        <div class="budget-item">
          <div class="budget-item-copy">
            <strong>${escapeHtml(category.name)}</strong>
            <small>${escapeHtml(category.group)}</small>
          </div>
          <input
            type="number"
            inputmode="decimal"
            min="0"
            step="10"
            value="${category.budget}"
            data-budget-category="${escapeHtml(category.name)}"
            aria-label="${escapeHtml(category.name)} monthly budget"
          />
          <button
            type="button"
            class="ghost-button budget-delete-btn"
            data-delete-category="${escapeHtml(category.name)}"
            aria-label="Delete ${escapeHtml(category.name)}"
          >Delete</button>
        </div>
      `,
    )
    .join("");
}

function deleteCategoryFromBudgets(name) {
  const index = state.categories.findIndex((category) => category.name === name && category.type === "Expense");
  if (index === -1) return;
  const [removed] = state.categories.splice(index, 1);
  saveState();
  populateCategorySelect();
  populateRecurringCategorySelect();
  renderBudgetEditor();
  updateBudgetsSummary();
  renderDashboard();
  showToast(`${name} removed.`, "success", {
    actionLabel: "Undo",
    duration: 5000,
    onAction: () => {
      state.categories.splice(Math.min(index, state.categories.length), 0, removed);
      saveState();
      populateCategorySelect();
      populateRecurringCategorySelect();
      renderBudgetEditor();
      updateBudgetsSummary();
      render();
      showToast("Category restored.");
    },
  });
}

function addCategoryFromBudgetPanel() {
  const nameCheck = validateCategoryName(elements.categoryBuilderNameInput.value);
  if (!nameCheck.ok) {
    setCategoryBuilderMessage(nameCheck.message, true);
    return;
  }
  const name = nameCheck.value;

  if (categoryExists(state.categories, name)) {
    setCategoryBuilderMessage(`${name} already exists. Update its budget above.`, true);
    return;
  }

  const budget = Number(elements.categoryBuilderBudgetInput.value);
  state.categories.push({
    name,
    type: "Expense",
    group: normalizeCategoryGroup(elements.categoryBuilderGroupInput.value),
    budget: Number.isFinite(budget) && budget >= 0 ? Math.min(budget, 1_000_000_000) : 0,
  });
  saveState();
  populateCategorySelect();
  populateRecurringCategorySelect();
  renderBudgetEditor();
  updateBudgetsSummary();
  render();
  elements.categoryBuilderForm.reset();
  setCategoryBuilderMessage(`${name} added.`);
}

function setCategoryBuilderMessage(message, isError = false) {
  elements.categoryBuilderMessage.textContent = message;
  elements.categoryBuilderMessage.style.color = isError ? "var(--red)" : "var(--muted)";
}

function populateCategorySelect() {
  const type = elements.typeInput.value;
  const categories = state.categories.filter((category) => category.type === type);
  elements.categoryInput.innerHTML = categories.map((category) => `<option>${escapeHtml(category.name)}</option>`).join("");
  const preferred = type === "Income" ? "Salary" : "Groceries";
  if (categories.some((category) => category.name === preferred)) {
    elements.categoryInput.value = preferred;
  }
}

function loadQuickAddPrefs() {
  try {
    return JSON.parse(localStorage.getItem(QUICK_ADD_PREFS_KEY)) || {};
  } catch {
    return {};
  }
}

function saveQuickAddPrefs(prefs) {
  try {
    localStorage.setItem(QUICK_ADD_PREFS_KEY, JSON.stringify(prefs));
  } catch {
    // Storage blocked — defaults still apply next open.
  }
}

function openQuickAdd() {
  quickAdd.open = true;
  quickAdd.amount = "";
  quickAdd.type = "Expense";
  elements.qaDateInput.value = defaultDateForMonth(elements.monthInput.value);
  elements.qaDescriptionInput.value = "";
  elements.qaAccountInput.innerHTML = accounts
    .map((account) => `<option>${escapeHtml(account)}</option>`)
    .join("");
  const prefs = loadQuickAddPrefs();
  if (accounts.includes(prefs.account)) elements.qaAccountInput.value = prefs.account;
  syncQuickAddTypeButtons();
  populateQuickAddCategories();
  renderQuickAddAmount();
  setQuickAddMessage("");
  elements.quickAddSheet.hidden = false;
  elements.qaSubmitBtn.focus({ preventScroll: true });
}

function closeQuickAdd() {
  quickAdd.open = false;
  elements.quickAddSheet.hidden = true;
}

function setQuickAddType(type) {
  if (type !== "Expense" && type !== "Income") return;
  quickAdd.type = type;
  syncQuickAddTypeButtons();
  populateQuickAddCategories();
}

function syncQuickAddTypeButtons() {
  elements.qaTypeToggle.querySelectorAll("[data-qa-type]").forEach((node) => {
    node.classList.toggle("is-active", node.dataset.qaType === quickAdd.type);
  });
  elements.qaSubmitBtn.textContent = quickAdd.type === "Income" ? "Add income" : "Add expense";
}

function populateQuickAddCategories() {
  const categories = state.categories.filter((category) => category.type === quickAdd.type);
  elements.qaCategoryInput.innerHTML = categories
    .map((category) => `<option>${escapeHtml(category.name)}</option>`)
    .join("");
  const lastUsed = loadQuickAddPrefs().categories?.[quickAdd.type];
  const preferred = categories.some((category) => category.name === lastUsed)
    ? lastUsed
    : quickAdd.type === "Income"
      ? "Salary"
      : "Groceries";
  if (categories.some((category) => category.name === preferred)) {
    elements.qaCategoryInput.value = preferred;
  }
}

function pressQuickAddKey(key) {
  let next = quickAdd.amount;
  if (key === "back") {
    next = next.slice(0, -1);
  } else if (key === ".") {
    if (next.includes(".")) return;
    next = next ? `${next}.` : "0.";
  } else if (/^[0-9]$/.test(key)) {
    const decimals = next.split(".")[1];
    if (decimals !== undefined && decimals.length >= 2) return;
    if (next === "0") {
      next = key;
    } else {
      if (next.replace(".", "").length >= 9) return;
      next += key;
    }
  } else {
    return;
  }
  quickAdd.amount = next;
  renderQuickAddAmount();
  setQuickAddMessage("");
}

function renderQuickAddAmount() {
  const [whole = "", decimals] = quickAdd.amount.split(".");
  const grouped = whole ? Number(whole).toLocaleString("en-US") : "0";
  elements.qaAmountDisplay.textContent =
    decimals === undefined ? `$${grouped}` : `$${grouped}.${decimals}`;
  elements.qaAmountDisplay.classList.toggle("is-empty", !quickAdd.amount);
}

function setQuickAddMessage(message, isError = false) {
  elements.qaMessage.textContent = message;
  elements.qaMessage.style.color = isError ? "var(--red)" : "var(--muted)";
}

function submitQuickAdd() {
  const dateCheck = validateDate(elements.qaDateInput.value);
  const amountCheck = validateAmount(quickAdd.amount);
  const typeCheck = validateTransactionType(quickAdd.type);
  const categoryCheck = validateCategoryName(elements.qaCategoryInput.value);
  const descriptionCheck = validateDescription(
    elements.qaDescriptionInput.value.trim() || elements.qaCategoryInput.value,
  );
  if (!dateCheck.ok || !amountCheck.ok || !typeCheck.ok || !categoryCheck.ok || !descriptionCheck.ok) {
    setQuickAddMessage(
      amountCheck.message || dateCheck.message || typeCheck.message || categoryCheck.message || descriptionCheck.message,
      true,
    );
    return;
  }

  const item = stampAuthor(
    transaction(
      dateCheck.value,
      typeCheck.value,
      categoryCheck.value,
      descriptionCheck.value,
      elements.qaAccountInput.value,
      amountCheck.value,
    ),
  );
  state.transactions.push(item);
  saveState();

  const prefs = loadQuickAddPrefs();
  prefs.account = elements.qaAccountInput.value;
  prefs.categories = { ...prefs.categories, [quickAdd.type]: categoryCheck.value };
  saveQuickAddPrefs(prefs);

  closeQuickAdd();
  render();
  showToast(`Added ${MONEY_CENTS_FORMAT.format(item.amount)} — ${item.category}.`);
}

function clampedRecurringDay(item, year, monthNumber) {
  return Math.min(item.dayOfMonth, new Date(year, monthNumber, 0).getDate());
}

/** Post any recurring items due in the CURRENT real month that haven't posted yet. */
function postDueRecurring() {
  const monthKey = currentMonthKey();
  const [year, monthNumber] = monthKey.split("-").map(Number);
  const today = new Date().getDate();
  let posted = 0;
  for (const item of state.recurring || []) {
    const day = clampedRecurringDay(item, year, monthNumber);
    if (item.lastPostedMonth === monthKey || today < day) continue;
    const date = `${monthKey}-${String(day).padStart(2, "0")}`;
    state.transactions.push(
      transaction(date, item.type, item.category, item.description, item.account, item.amount),
    );
    item.lastPostedMonth = monthKey;
    posted += 1;
  }
  if (posted) {
    saveState();
    render();
    showToast(posted === 1 ? "Posted 1 recurring transaction." : `Posted ${posted} recurring transactions.`);
  }
}

function nextRecurringDate(item) {
  const monthKey = currentMonthKey();
  const [year, monthNumber] = monthKey.split("-").map(Number);
  const today = new Date().getDate();
  if (item.lastPostedMonth !== monthKey && today <= clampedRecurringDay(item, year, monthNumber)) {
    return new Date(year, monthNumber - 1, clampedRecurringDay(item, year, monthNumber));
  }
  const nextYear = monthNumber === 12 ? year + 1 : year;
  const nextMonth = monthNumber === 12 ? 1 : monthNumber + 1;
  return new Date(nextYear, nextMonth - 1, clampedRecurringDay(item, nextYear, nextMonth));
}

function renderUpcoming() {
  if (!elements.upcomingPanel) return;
  const horizon = new Date();
  horizon.setDate(horizon.getDate() + 14);
  const due = (state.recurring || [])
    .map((item) => ({ item, date: nextRecurringDate(item) }))
    .filter((entry) => entry.date <= horizon)
    .sort((a, b) => a.date - b.date);
  elements.upcomingPanel.hidden = !due.length;
  if (!due.length) return;
  const dayFormat = new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric" });
  elements.upcomingList.innerHTML = due
    .map(
      ({ item, date }) => `
        <div class="upcoming-row">
          <span class="upcoming-date">${dayFormat.format(date)}</span>
          <span class="upcoming-name">${escapeHtml(item.description)}</span>
          <span class="upcoming-amount ${item.type === "Income" ? "is-income" : ""}">${item.type === "Income" ? "+" : ""}${money(item.amount)}</span>
        </div>
      `,
    )
    .join("");
}

function renderRecurringList() {
  if (!elements.recurringList) return;
  const items = state.recurring || [];
  if (!items.length) {
    elements.recurringList.innerHTML = `<p class="recurring-empty">Nothing recurring yet — add your rent, subscriptions, or paycheck below.</p>`;
    return;
  }
  elements.recurringList.innerHTML = items
    .map(
      (item) => `
        <div class="recurring-row">
          <div class="recurring-copy">
            <strong>${escapeHtml(item.description)}</strong>
            <small>${escapeHtml(item.category)} · ${escapeHtml(item.account)} · day ${item.dayOfMonth}</small>
          </div>
          <span class="upcoming-amount ${item.type === "Income" ? "is-income" : ""}">${item.type === "Income" ? "+" : ""}${money(item.amount)}</span>
          <button class="delete-button" data-recurring-id="${escapeHtml(item.id)}" type="button">Delete</button>
        </div>
      `,
    )
    .join("");
}

function populateRecurringCategorySelect() {
  if (!elements.recCategoryInput) return;
  const type = elements.recTypeInput.value;
  const categories = state.categories.filter((category) => category.type === type);
  elements.recCategoryInput.innerHTML = categories
    .map((category) => `<option>${escapeHtml(category.name)}</option>`)
    .join("");
}

function setRecurringMessage(message, isError = false) {
  elements.recurringMessage.textContent = message;
  elements.recurringMessage.style.color = isError ? "var(--red)" : "var(--muted)";
}

function addRecurringFromForm() {
  const typeCheck = validateTransactionType(elements.recTypeInput.value);
  const categoryCheck = validateCategoryName(elements.recCategoryInput.value);
  const amountCheck = validateAmount(elements.recAmountInput.value);
  const descriptionCheck = validateDescription(
    elements.recDescriptionInput.value.trim() || elements.recCategoryInput.value,
  );
  const day = Math.round(Number(elements.recDayInput.value));
  if (!Number.isFinite(day) || day < 1 || day > 31) {
    setRecurringMessage("Day of month must be between 1 and 31.", true);
    return;
  }
  if (!typeCheck.ok || !categoryCheck.ok || !amountCheck.ok || !descriptionCheck.ok) {
    setRecurringMessage(
      typeCheck.message || categoryCheck.message || amountCheck.message || descriptionCheck.message,
      true,
    );
    return;
  }

  const monthKey = currentMonthKey();
  const [year, monthNumber] = monthKey.split("-").map(Number);
  const item = {
    id: crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}-${Math.random()}`,
    type: typeCheck.value,
    category: categoryCheck.value,
    description: descriptionCheck.value,
    account: elements.recAccountInput.value,
    amount: amountCheck.value,
    dayOfMonth: day,
    // Past this month's day already? Start next month so we don't double a bill
    // the user probably logged by hand.
    lastPostedMonth:
      new Date().getDate() > Math.min(day, new Date(year, monthNumber, 0).getDate()) ? monthKey : "",
  };
  state.recurring = state.recurring || [];
  state.recurring.push(item);
  saveState();
  elements.recurringForm.reset();
  elements.recDayInput.value = "1";
  populateRecurringCategorySelect();
  setRecurringMessage(`${item.description} will post on day ${item.dayOfMonth} each month.`);
  renderRecurringList();
  postDueRecurring();
}

function getMonthSummary(month) {
  // Single pass over transactions; same results as the old per-category filters.
  const monthTransactions = [];
  let income = 0;
  let expenses = 0;
  let incomeCount = 0;
  let expenseCount = 0;
  const spentByCategory = new Map();
  for (const item of state.transactions) {
    if (monthKeyFromDate(item.date) !== month) continue;
    monthTransactions.push(item);
    if (item.type === "Income") {
      income += item.amount;
      incomeCount += 1;
    } else if (item.type === "Expense") {
      expenses += item.amount;
      expenseCount += 1;
      spentByCategory.set(item.category, (spentByCategory.get(item.category) || 0) + item.amount);
    }
  }

  let totalBudget = 0;
  const categoryRows = [];
  for (const category of state.categories) {
    if (category.type !== "Expense") continue;
    totalBudget += category.budget;
    const spent = spentByCategory.get(category.name) || 0;
    categoryRows.push({ ...category, spent, left: category.budget - spent });
  }
  categoryRows.sort((a, b) => b.spent - a.spent || b.budget - a.budget);

  return {
    monthTransactions,
    income,
    expenses,
    totalBudget,
    incomeCount,
    expenseCount,
    categoryRows,
  };
}

function getPayPeriodSummary(month) {
  const profile = normalizeSetupProfile(state.setupProfile);
  const firstOfMonth = `${month}-01`;
  const isCurrentMonth = month === currentMonthKey();
  const referenceDate = isCurrentMonth ? todayString() : firstOfMonth;
  let period = getPayPeriodForDate(referenceDate, profile);
  // When browsing a non-current month, a pay period that started in the prior
  // month belongs to that month, not this one — advance to the first period
  // that actually starts within the viewed month. Only interval schedules
  // (weekly/biweekly) straddle; monthly/semimonthly periods start on the 1st,
  // so this never fires for them.
  if (!isCurrentMonth && period.start < firstOfMonth) {
    const dayAfterPeriod = toDateString(addDays(parseLocalDate(period.end), 1));
    period = getPayPeriodForDate(dayAfterPeriod, profile);
  }
  const periodTransactions = state.transactions.filter((item) => dateInRange(item.date, period.start, period.end));
  const incomeItems = periodTransactions.filter((item) => item.type === "Income");
  const expenseItems = periodTransactions.filter((item) => item.type === "Expense");
  const loggedIncome = sum(incomeItems.map((item) => item.amount));
  // Same basis as the Income metric: logged paycheck income, else configured check amount.
  const income = loggedIncome > 0 ? loggedIncome : (profile.payAmount || 0);
  const expenses = sum(expenseItems.map((item) => item.amount));
  // Check left must use the same income shown above (never a hidden different basis).
  const left = income - expenses;
  const expenseCategories = state.categories.filter((category) => category.type === "Expense");
  const categoryRows = expenseCategories
    .map((category) => ({
      ...category,
      spent: sum(expenseItems.filter((item) => item.category === category.name).map((item) => item.amount)),
    }))
    .sort((a, b) => b.spent - a.spent);

  return {
    ...period,
    label: `${payFrequencies[profile.payFrequency]?.name || "Paycheck"} view`,
    rangeLabel: formatPayPeriodRange(period.start, period.end),
    income,
    expenses,
    left,
    categoryRows,
  };
}

function createEmptyState() {
  return {
    categories: structuredClone(defaultCategories).map((category) => ({
      ...category,
      budget: category.type === "Expense" ? 0 : category.budget,
    })),
    transactions: [],
    recurring: [],
    savingsGoals: [],
    setupComplete: false,
    setupProfile: null,
  };
}

function createDemoState() {
  return {
    categories: structuredClone(defaultCategories),
    transactions: structuredClone(defaultTransactions),
    // lastPostedMonth = current month so demo data doesn't auto-post on load.
    recurring: [
      {
        id: "demo-recurring-rent",
        type: "Expense",
        category: "Housing",
        description: "Rent",
        account: "Checking",
        amount: 1800,
        dayOfMonth: 1,
        lastPostedMonth: currentMonthKey(),
      },
      {
        id: "demo-recurring-internet",
        type: "Expense",
        category: "Utilities",
        description: "Internet bill",
        account: "Checking",
        amount: 60,
        dayOfMonth: 25,
        lastPostedMonth: "",
      },
    ],
    savingsGoals: [
      {
        id: "demo-goal-emergency",
        name: "Emergency fund",
        target: 3000,
        current: 750,
      },
    ],
    setupComplete: true,
    setupProfile: {
      presetId: "single",
      income: 4550,
      payAmount: 2100,
      payFrequency: "biweekly",
      nextPayDate: "2026-07-10",
      completedAt: new Date().toISOString(),
      demo: true,
    },
  };
}

function normalizeSetupProfile(profile) {
  const payFrequency = profile?.payFrequency || "biweekly";
  const payAmount = Number(profile?.payAmount) > 0 ? Number(profile.payAmount) : 0;
  const income = Number(profile?.income) > 0
    ? Number(profile.income)
    : monthlyIncomeFromPay(payAmount, payFrequency);
  return {
    presetId: profile?.presetId || "single",
    income,
    payAmount,
    payFrequency,
    nextPayDate: profile?.nextPayDate || nextDefaultPayDate(payFrequency),
    completedAt: profile?.completedAt || null,
    demo: Boolean(profile?.demo),
  };
}

function cacheKey(uid) {
  return `${STORAGE_KEY}:uid:${uid}`;
}

function readCachePayload(uid) {
  try {
    const stored = JSON.parse(localStorage.getItem(cacheKey(uid)));
    if (stored?.state?.categories?.length && Array.isArray(stored.state.transactions)) return stored;
  } catch {
    localStorage.removeItem(cacheKey(uid));
  }
  return null;
}

function writeCachePayload(uid, payload) {
  try {
    localStorage.setItem(cacheKey(uid), JSON.stringify(payload));
  } catch {
    showToast("Storage full — export a backup and clear old data.", "error");
  }
}

function cleanProfileName(value) {
  return String(value || "").trim().replace(/\s+/g, " ").slice(0, 20);
}

function legacyProfileName() {
  try {
    const registry = JSON.parse(localStorage.getItem(PROFILES_KEY));
    return registry?.active || "";
  } catch {
    return "";
  }
}

// Pre-sync data from earlier versions of the app (device-locked or original)
function readLegacyState() {
  const name = legacyProfileName();
  const keys = [name ? `${STORAGE_KEY}:${name.toLowerCase()}` : null, STORAGE_KEY].filter(Boolean);
  for (const key of keys) {
    try {
      const stored = JSON.parse(localStorage.getItem(key));
      if (stored?.categories?.length && Array.isArray(stored.transactions)) return stored;
    } catch {
      // ignore corrupted legacy data
    }
  }
  return null;
}

function normalizeState(raw) {
  // Whitelist fields — never spread arbitrary import/cloud keys into app state.
  const sanitized = sanitizeBudgetState(raw);
  const setupProfile = sanitized.setupProfile ? normalizeSetupProfile(sanitized.setupProfile) : null;
  const transactions = stripAutoGeneratedPaychecks(sanitized.transactions || []);
  const categories =
    sanitized.categories?.length > 0
      ? sanitized.categories
      : createEmptyState().categories;
  return {
    categories,
    transactions,
    recurring: sanitized.recurring || [],
    savingsGoals: sanitized.savingsGoals || [],
    setupComplete: sanitized.setupComplete ?? true,
    setupProfile,
  };
}

function openAuthGate() {
  setAuthMode("signin");
  if (sessionStorage.getItem(PENDING_JOIN_KEY)) {
    setAuthMessage("Sign in — or create an account — to join the shared budget.");
  }
  elements.authGate.hidden = false;
  document.body.classList.add("wizard-open");
  if (elements.tabBar) elements.tabBar.hidden = true;
  elements.authEmailInput.focus();
}

function closeAuthGate() {
  elements.authGate.hidden = true;
  if (elements.tabBar) elements.tabBar.hidden = false;
  if (elements.setupWizard.hidden && elements.editDialog.hidden) {
    document.body.classList.remove("wizard-open");
  }
}

function setAuthMode(mode) {
  authMode = mode;
  const signup = mode === "signup";
  const recovery = mode === "recovery";
  const confirm = mode === "confirm";

  elements.authTitle.textContent = confirm
    ? "Check your email"
    : recovery
      ? "Choose a new password"
      : signup
        ? "Create your account"
        : "Welcome back";
  elements.authCopy.textContent = confirm
    ? `We sent a confirmation link to ${pendingConfirmEmail}. Open it on this device, then come back and sign in. Nothing there? Check spam, or make sure the address above is right.`
    : recovery
      ? `Enter a new password for your Budget Studio account. ${AUTH_PASSWORD_HINT}.`
      : "Sign in and your budget follows you on every device — private to your account only.";

  elements.authNameLabel.hidden = !signup;
  elements.authNameInput.required = signup;
  elements.authEmailLabel.hidden = recovery || confirm;
  elements.authEmailInput.required = !recovery && !confirm;
  elements.authPasswordLabel.hidden = confirm;
  elements.authPasswordInput.required = !confirm;
  elements.authPasswordLabelText.textContent = recovery ? "New password" : "Password";
  elements.authPasswordInput.placeholder = signup || recovery ? AUTH_PASSWORD_HINT : "Your password";
  if (elements.authPasswordHelp) {
    // Persistent rule text — the placeholder disappears as soon as typing starts.
    elements.authPasswordHelp.textContent = AUTH_PASSWORD_HINT;
    elements.authPasswordHelp.hidden = !(signup || recovery);
  }
  elements.authPasswordInput.minLength = signup || recovery ? 8 : 1;
  elements.authPasswordInput.autocomplete = signup || recovery ? "new-password" : "current-password";
  elements.authSubmitBtn.hidden = confirm;
  elements.authSubmitBtn.textContent = recovery ? "Save new password" : signup ? "Create account" : "Sign in";
  elements.authConfirmedBtn.hidden = !confirm;
  elements.authResendBtn.hidden = !confirm;
  if (!confirm) stopConfirmWatch();
  elements.authModeToggleBtn.hidden = recovery;
  elements.authForgotBtn.hidden = signup || recovery || confirm;
  elements.authModeToggleBtn.textContent = confirm
    ? "Back to sign in"
    : signup
      ? "Already have an account? Sign in"
      : "New here? Create an account";
  setAuthMessage("");
}

let pendingConfirmEmail = "";
let pendingConfirmPassword = ""; // memory only, never persisted; enables auto sign-in once confirmed
let resendCooldownTimer = null;
let confirmWatchTimer = null;
let confirmWatchBusy = false;

function showConfirmEmailState(email, message = "", password = "") {
  pendingConfirmEmail = email;
  pendingConfirmPassword = password;
  setAuthMode("confirm");
  if (message) setAuthMessage(message);
  startConfirmWatch();
}

function stopConfirmWatch() {
  if (confirmWatchTimer) clearInterval(confirmWatchTimer);
  confirmWatchTimer = null;
  pendingConfirmPassword = "";
}

function startConfirmWatch() {
  if (confirmWatchTimer) clearInterval(confirmWatchTimer);
  if (!pendingConfirmPassword) return;
  // Quietly retry sign-in while this screen waits; succeeds the moment the
  // link is clicked on any device. Unconfirmed attempts don't count toward lockout.
  confirmWatchTimer = setInterval(() => {
    if (document.visibilityState === "visible") attemptConfirmedSignIn(true);
  }, 15000);
}

async function attemptConfirmedSignIn(silent = false) {
  if (authMode !== "confirm" || confirmWatchBusy) return;
  if (!pendingConfirmPassword) {
    if (!silent) {
      // No retained password (e.g. page was reloaded) — hand off to normal sign-in.
      const email = pendingConfirmEmail;
      setAuthMode("signin");
      elements.authEmailInput.value = email;
      setAuthMessage("Enter your password to sign in.");
      elements.authPasswordInput.focus();
    }
    return;
  }
  confirmWatchBusy = true;
  if (!silent) setAuthMessage("Signing you in...");
  try {
    await signIn(pendingConfirmEmail, pendingConfirmPassword);
    stopConfirmWatch();
    // onAuthStateChanged drives the rest
  } catch (error) {
    const unconfirmed = error?.code === "email_not_confirmed" || /email not confirmed/i.test(String(error?.message || ""));
    if (!silent) {
      setAuthMessage(
        unconfirmed
          ? "Not confirmed yet — the link may take a minute to register. Try again shortly."
          : friendlyAuthError(error),
        true,
      );
    } else if (!unconfirmed) {
      // Silent retry hit a real error (lockout, network) — stop hammering.
      stopConfirmWatch();
    }
  } finally {
    confirmWatchBusy = false;
  }
}

function startResendCooldown(seconds = 60) {
  if (resendCooldownTimer) clearInterval(resendCooldownTimer);
  let left = seconds;
  elements.authResendBtn.disabled = true;
  elements.authResendBtn.textContent = `Resend email (${left}s)`;
  resendCooldownTimer = setInterval(() => {
    left -= 1;
    if (left <= 0) {
      clearInterval(resendCooldownTimer);
      resendCooldownTimer = null;
      elements.authResendBtn.disabled = false;
      elements.authResendBtn.textContent = "Resend confirmation email";
    } else {
      elements.authResendBtn.textContent = `Resend email (${left}s)`;
    }
  }, 1000);
}

async function handleResendConfirmation() {
  if (!pendingConfirmEmail || elements.authResendBtn.disabled) return;
  elements.authResendBtn.disabled = true;
  setAuthMessage("Sending a new confirmation email...");
  try {
    await resendConfirmation(pendingConfirmEmail);
    setAuthMessage("New email sent. Give it a minute, and check spam too.");
  } catch (error) {
    setAuthMessage(friendlyAuthError(error), true);
  }
  // Cooldown either way — the free email service allows only a couple of sends per hour.
  startResendCooldown();
}

async function handleForgotPassword() {
  const lock = getAuthLockout();
  if (lock.locked) {
    setAuthMessage(`Too many attempts. Wait ${Math.ceil(lock.retryAfterMs / 1000)}s and try again.`, true);
    return;
  }
  const emailCheck = validateEmail(elements.authEmailInput.value);
  if (!emailCheck.ok) {
    setAuthMessage("Enter your email first, then tap Forgot password.", true);
    elements.authEmailInput.focus();
    return;
  }
  elements.authForgotBtn.disabled = true;
  setAuthMessage("Sending reset email...");
  try {
    await resetPassword(emailCheck.value);
    // Generic success — do not reveal whether the email exists.
    setAuthMessage("If an account exists for that email, a reset link is on the way. Check spam if nothing arrives.");
  } catch (error) {
    setAuthMessage(friendlyAuthError(error), true);
  } finally {
    elements.authForgotBtn.disabled = false;
  }
}

function setAuthMessage(message, isError = false) {
  elements.authMessage.textContent = message;
  elements.authMessage.style.color = isError ? "var(--red)" : "var(--muted)";
}

async function handleAuthSubmit(event) {
  event.preventDefault();
  if (authMode === "confirm") return; // no submit action in the check-your-email state
  const lock = getAuthLockout();
  if (lock.locked) {
    setAuthMessage(`Too many attempts. Wait ${Math.ceil(lock.retryAfterMs / 1000)}s and try again.`, true);
    return;
  }

  const email = elements.authEmailInput.value.trim();
  const password = elements.authPasswordInput.value;
  const name = cleanProfileName(elements.authNameInput.value);

  if (authMode === "recovery") {
    const passwordCheck = validatePassword(password);
    if (!passwordCheck.ok) {
      setAuthMessage(passwordCheck.message, true);
      return;
    }
    elements.authSubmitBtn.disabled = true;
    setAuthMessage("Saving new password...");
    try {
      await updatePassword(passwordCheck.value);
      elements.authPasswordInput.value = "";
      // Drop recovery tokens from the URL hash so the elevated recovery session is not re-triggered.
      history.replaceState(null, "", `${window.location.pathname}${window.location.search}`);
      authMode = "signin";
      setAuthMessage("Password updated. Loading your budget...");
      showToast("Password updated.");
      // Load budget now that recovery is complete (handleUserChanged skipped sync during recovery).
      if (currentUser) {
        closeAuthGate();
        await handleUserChanged(currentUser, {});
      } else {
        setAuthMode("signin");
      }
    } catch (error) {
      setAuthMessage(friendlyAuthError(error), true);
    } finally {
      elements.authSubmitBtn.disabled = false;
    }
    return;
  }

  if (authMode === "signup" && !name) {
    setAuthMessage("Type your name first.", true);
    return;
  }

  const emailCheck = validateEmail(email);
  if (!emailCheck.ok) {
    setAuthMessage(emailCheck.message, true);
    return;
  }

  if (authMode === "signup") {
    const passwordCheck = validatePassword(password);
    if (!passwordCheck.ok) {
      setAuthMessage(passwordCheck.message, true);
      return;
    }
  } else if (!password) {
    setAuthMessage("Enter your password.", true);
    return;
  }

  elements.authSubmitBtn.disabled = true;
  setAuthMessage(authMode === "signup" ? "Creating your account..." : "Signing in...");
  try {
    if (authMode === "signup") {
      const result = await signUp(name, emailCheck.value, password);
      elements.authPasswordInput.value = "";
      clearAuthFailures();
      if (result.existingAccount) {
        setAuthMode("signin");
        elements.authEmailInput.value = emailCheck.value;
        setAuthMessage("That email is already registered. Sign in below, or tap Forgot password.", true);
      } else if (result.confirmationRequired) {
        showConfirmEmailState(emailCheck.value, "", password);
        // A confirmation email just went out with the signup; hold resend briefly.
        startResendCooldown();
      }
      // Otherwise onAuthStateChanged drives the rest.
    } else {
      await signIn(emailCheck.value, password);
      elements.authPasswordInput.value = "";
      clearAuthFailures();
      // onAuthStateChanged drives the rest
    }
  } catch (error) {
    safeLog("warn", "Auth submit failed", { mode: authMode });
    if (error?.code === "email_not_confirmed" || /email not confirmed/i.test(String(error?.message || ""))) {
      showConfirmEmailState(emailCheck.value, "Your email isn't confirmed yet — find the link in your inbox, or resend it below.", password);
    } else {
      setAuthMessage(friendlyAuthError(error), true);
    }
  } finally {
    elements.authSubmitBtn.disabled = false;
  }
}

function clearLocalUserCaches(uid) {
  try {
    if (uid) localStorage.removeItem(cacheKey(uid));
    localStorage.removeItem(CLOUD_DIRTY_KEY);
    // Clear any legacy device-locked caches from older versions.
    const toRemove = [];
    for (let i = 0; i < localStorage.length; i += 1) {
      const key = localStorage.key(i);
      if (key && (key.startsWith(`${STORAGE_KEY}:uid:`) || key === STORAGE_KEY || key === PROFILES_KEY)) {
        toRemove.push(key);
      }
    }
    toRemove.forEach((key) => localStorage.removeItem(key));
  } catch {
    // ignore storage errors during logout
  }
  clearAuthFailures();
}

async function handleSignOut() {
  const uid = currentUser?.uid;
  try {
    if (!localOnlyMode) await signOutUser();
  } catch (error) {
    safeLog("warn", "Sign-out failed", { code: error?.code || "signout" });
  }
  clearLocalUserCaches(uid);
  currentUser = null;
  state = createEmptyState();
  renderIdentityUI();
  render();
  openAuthGate();
  showToast("Signed out.");
}

async function handleDeleteAccount() {
  if (localOnlyMode || !currentUser) {
    showToast("Sign in to manage your cloud account.", "error");
    return;
  }
  const confirmed = window.confirm(
    "Delete your cloud budget data and sign out?\n\n" +
      "• Removes your personal synced budget\n" +
      "• Leaves any shared budget (if you own it, that shared budget is deleted for everyone)\n" +
      "• Your Auth login may still exist until you delete it in Supabase (see Privacy)\n\n" +
      "Export a backup first if you need it.",
  );
  if (!confirmed) return;
  const uid = currentUser.uid;
  elements.deleteAccountBtn.disabled = true;
  try {
    teardownShared();
    await deleteOwnBudgetAndSignOut();
    clearLocalUserCaches(uid);
    currentUser = null;
    state = createEmptyState();
    renderIdentityUI();
    render();
    openAuthGate();
    setAuthMessage(
      "Your personal budget was deleted, shared membership was cleared, and you are signed out. To remove the login entirely, delete the user in Supabase Authentication.",
    );
    showToast("Cloud budget data deleted.");
  } catch (error) {
    showToast(friendlyAuthError(error), "error");
  } finally {
    elements.deleteAccountBtn.disabled = false;
  }
}

function renderIdentityUI() {
  const titles = {
    overview: "",
    activity: "Activity",
    goals: "Goals",
    settings: "Settings",
  };
  const onOverview = !titles[activeTab];
  if (onOverview) {
    // Safe-to-spend hero: what's left of the plan for the selected month.
    const month = elements.monthInput.value;
    const summary = getMonthSummary(month);
    const left = summary.totalBudget - summary.expenses;
    elements.appTitle.textContent = money(left);
    elements.appTitle.classList.toggle("is-negative", left < 0);
  } else {
    elements.appTitle.textContent = titles[activeTab];
    elements.appTitle.classList.remove("is-negative");
  }
  elements.appTitle.classList.toggle("hero-number", onOverview);
  if (elements.appSubtitle) {
    elements.appSubtitle.hidden = !onOverview;
    if (onOverview) elements.appSubtitle.textContent = `Safe to spend in ${formatMonthLabel(elements.monthInput.value)}`;
  }
  elements.signOutBtn.hidden = localOnlyMode || !currentUser;
  if (elements.deleteAccountBtn) {
    elements.deleteAccountBtn.hidden = localOnlyMode || !currentUser;
  }
  if (elements.tabBar) elements.tabBar.hidden = Boolean(elements.authGate && !elements.authGate.hidden);
}

function flushDirtyCloudSave() {
  if (localOnlyMode || !currentUser || currentUser.uid === "local" || !localStorage.getItem(CLOUD_DIRTY_KEY)) {
    return;
  }
  const payload = readCachePayload(currentUser.uid);
  if (!payload) {
    localStorage.removeItem(CLOUD_DIRTY_KEY);
    return;
  }
  (sharedBudget
    ? pushSharedBudget(sharedBudget.id, payload)
    : pushCloudBudget(currentUser.uid, { ...payload, name: currentUser.displayName || "" }))
    .then((result) => {
      localStorage.removeItem(CLOUD_DIRTY_KEY);
      didNotifySyncFailure = false;
      const serverAt = Number(result?.updatedAt) || 0;
      if (serverAt > 0) {
        if (sharedBudget) lastSharedAppliedAt = serverAt;
        writeCachePayload(currentUser.uid, {
          ...payload,
          updatedAt: serverAt,
          name: currentUser.displayName || "",
        });
      }
    })
    .catch(() => {});
}

function loadState() {
  if (!currentUser) return createEmptyState();
  if (localOnlyMode) {
    const legacy = readLegacyState();
    return legacy ? normalizeState(legacy) : createEmptyState();
  }
  const payload = readCachePayload(currentUser.uid);
  return payload ? normalizeState(payload.state) : createEmptyState();
}

function saveState() {
  if (!currentUser) return;
  if (localOnlyMode || currentUser.uid === "local") {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    } catch {
      showToast("Storage full — export a backup and clear old data.", "error");
    }
    return;
  }

  const payload = { state, updatedAt: Date.now(), name: currentUser.displayName || "" };
  writeCachePayload(currentUser.uid, payload);
  if (sharedBudget) lastSharedAppliedAt = payload.updatedAt; // optimistic until server ack
  clearTimeout(cloudSaveTimer);
  // Debounce cloud push so rapid budget edits don't spam sync failures.
  cloudSaveTimer = setTimeout(() => {
    if (localOnlyMode || !currentUser || currentUser.uid === "local") return;
    (sharedBudget ? pushSharedBudget(sharedBudget.id, payload) : pushCloudBudget(currentUser.uid, payload))
      .then((result) => {
        localStorage.removeItem(CLOUD_DIRTY_KEY);
        didNotifySyncFailure = false;
        const serverAt = Number(result?.updatedAt) || 0;
        if (serverAt > 0) {
          if (sharedBudget) lastSharedAppliedAt = serverAt;
          writeCachePayload(currentUser.uid, { ...payload, updatedAt: serverAt });
        }
      })
      .catch(() => {
        localStorage.setItem(CLOUD_DIRTY_KEY, "1");
        if (!didNotifySyncFailure) {
          didNotifySyncFailure = true;
          showToast("Saved on this device. Cloud sync will retry shortly.", "error");
        }
      });
  }, 900);
}

function transaction(date, type, category, description, account, amount) {
  return {
    id: crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}-${Math.random()}`,
    date,
    type,
    category,
    description,
    account,
    amount: Number(amount),
  };
}

/** First word of a display name, for compact authorship tags. */
function firstName(displayName) {
  return String(displayName || "").trim().split(/\s+/)[0] || "";
}

/** Activity-row authorship chip. Empty for untagged (personal/older) rows. */
function authorTag(item) {
  if (!item.addedBy) return "";
  const label = item.addedBy === currentUser?.uid ? "You" : item.addedByName || "Partner";
  return ` <span class="tx-author">${escapeHtml(label)}</span>`;
}

/**
 * Stamp who added a transaction — only inside a shared budget, where "who
 * bought what" matters. Personal budgets stay untagged. Mutates and returns.
 */
function stampAuthor(item) {
  if (sharedBudget && currentUser && currentUser.uid !== "local") {
    item.addedBy = currentUser.uid;
    item.addedByName = firstName(currentUser.displayName) || "Partner";
  }
  return item;
}

/** Matches income rows invented by the old setup wizard (e.g. "Biweekly paycheck"). */
function isAutoGeneratedPaycheck(tx) {
  return (
    tx?.type === "Income" &&
    tx.category === "Salary" &&
    tx.account === "Checking" &&
    /^(Weekly|Biweekly|Twice a month|Monthly|Paycheck) paycheck$/.test(String(tx.description || ""))
  );
}

function stripAutoGeneratedPaychecks(transactions) {
  if (!Array.isArray(transactions)) return [];
  return transactions.filter((tx) => !isAutoGeneratedPaycheck(tx));
}

function exportCsv() {
  const header = ["Date", "Type", "Category", "Description", "Account", "Amount"];
  const rows = state.transactions.map((item) => [
    item.date,
    item.type,
    item.category,
    item.description,
    item.account,
    item.amount,
  ]);
  const csv = [header, ...rows].map((row) => row.map(csvCell).join(",")).join("\n");
  download(`budget-transactions-${elements.monthInput.value}.csv`, "text/csv", csv);
  showToast("CSV exported.");
}

function exportJson() {
  download("budget-studio-backup.json", "application/json", JSON.stringify(state, null, 2));
  showToast("Backup downloaded.");
}

/**
 * Split CSV text into rows of fields. Handles quoted cells containing commas,
 * escaped quotes ("") and newlines, plus CRLF line endings.
 */
function parseCsvRows(text) {
  const rows = [];
  let row = [];
  let field = "";
  let inQuotes = false;
  for (let i = 0; i < text.length; i += 1) {
    const char = text[i];
    if (inQuotes) {
      if (char === '"') {
        if (text[i + 1] === '"') {
          field += '"';
          i += 1;
        } else {
          inQuotes = false;
        }
      } else {
        field += char;
      }
    } else if (char === '"') {
      inQuotes = true;
    } else if (char === ",") {
      row.push(field);
      field = "";
    } else if (char === "\n") {
      row.push(field);
      rows.push(row);
      row = [];
      field = "";
    } else if (char !== "\r") {
      field += char;
    }
  }
  if (field.length || row.length) {
    row.push(field);
    rows.push(row);
  }
  return rows.filter((cells) => cells.some((cell) => cell.trim() !== ""));
}

/**
 * Turn CSV text into validated transactions. Matches the Export CSV columns
 * (Date, Type, Category, Description, Account, Amount); maps by header name
 * when a header row is present, else assumes that column order. Invalid rows
 * are skipped, not fatal.
 */
function parseTransactionsCsv(text) {
  const rows = parseCsvRows(text);
  if (!rows.length) return { added: [], skipped: 0 };

  const fields = ["date", "type", "category", "description", "account", "amount"];
  let colMap = { date: 0, type: 1, category: 2, description: 3, account: 4, amount: 5 };
  let startIndex = 0;

  const firstLower = rows[0].map((cell) => cell.trim().toLowerCase());
  if (fields.some((name) => firstLower.includes(name))) {
    startIndex = 1;
    const mapped = {};
    fields.forEach((name) => {
      const idx = firstLower.indexOf(name);
      if (idx !== -1) mapped[name] = idx;
    });
    // Only trust header mapping if the essential columns are present.
    if (mapped.date !== undefined && mapped.type !== undefined && mapped.amount !== undefined) {
      colMap = { ...colMap, ...mapped };
    }
  }

  const added = [];
  let skipped = 0;
  for (let i = startIndex; i < rows.length; i += 1) {
    const cells = rows[i];
    const cell = (name) => (colMap[name] !== undefined ? String(cells[colMap[name]] ?? "").trim() : "");

    const dateCheck = validateDate(cell("date"));
    const typeCheck = validateTransactionType(cell("type"));
    // Tolerate "$1,234.56" style amounts from other apps.
    const amountCheck = validateAmount(cell("amount").replace(/[$,\s]/g, ""));
    const fallbackCategory = typeCheck.ok && typeCheck.value === "Income" ? "Salary" : "Groceries";
    const categoryCheck = validateCategoryName(cell("category") || fallbackCategory);
    const descriptionCheck = validateDescription(
      cell("description") || (categoryCheck.ok ? categoryCheck.value : "Imported"),
    );
    const accountCheck = validateAccountName(cell("account") || "Checking");

    if (
      !dateCheck.ok ||
      !typeCheck.ok ||
      !amountCheck.ok ||
      !categoryCheck.ok ||
      !descriptionCheck.ok ||
      !accountCheck.ok
    ) {
      skipped += 1;
      continue;
    }
    added.push(
      transaction(
        dateCheck.value,
        typeCheck.value,
        categoryCheck.value,
        descriptionCheck.value,
        accountCheck.value,
        amountCheck.value,
      ),
    );
  }
  return { added, skipped };
}

function importCsv(event) {
  const [file] = event.target.files;
  if (!file) return;
  try {
    assertImportFileSize(file.size);
  } catch (error) {
    setMessage(error.message || "Could not import that file.", true);
    event.target.value = "";
    return;
  }
  const reader = new FileReader();
  reader.addEventListener("load", () => {
    try {
      const { added, skipped } = parseTransactionsCsv(String(reader.result));
      if (!added.length) {
        throw new Error(
          skipped
            ? "No valid rows — expected columns: Date (YYYY-MM-DD), Type, Category, Description, Account, Amount."
            : "That file has no transaction rows.",
        );
      }
      // Non-destructive: CSV import adds to the current budget (use Restore to replace).
      state.transactions.push(...added);
      saveState();
      render();
      const skippedNote = skipped ? ` (${skipped} skipped)` : "";
      setMessage(`Imported ${added.length} transaction${added.length === 1 ? "" : "s"}${skippedNote}.`);
    } catch (error) {
      setMessage(error.message || "Could not import that file.", true);
    } finally {
      event.target.value = "";
    }
  });
  reader.readAsText(file);
}

function importJson(event) {
  const [file] = event.target.files;
  if (!file) return;
  try {
    assertImportFileSize(file.size);
  } catch (error) {
    setMessage(error.message || "Could not restore backup.", true);
    event.target.value = "";
    return;
  }
  const reader = new FileReader();
  reader.addEventListener("load", () => {
    try {
      const imported = JSON.parse(String(reader.result));
      if (!imported || typeof imported !== "object" || Array.isArray(imported)) {
        throw new Error("Invalid backup format.");
      }
      if (!Array.isArray(imported.categories) || !Array.isArray(imported.transactions)) {
        throw new Error("Invalid backup format.");
      }
      // Import only mutates the signed-in user's local/cloud row via saveState() —
      // never accepts a foreign user_id from the JSON.
      if (imported.user_id || imported.userId || imported.uid) {
        // Strip identity fields; cloud ownership comes from the session only.
        delete imported.user_id;
        delete imported.userId;
        delete imported.uid;
      }
      state = normalizeState(imported);
      if (!state.categories.length) {
        throw new Error("Backup has no valid categories.");
      }
      saveState();
      populateCategorySelect();
      render();
      setMessage("Backup restored.");
    } catch (error) {
      setMessage(error.message || "Could not restore backup.", true);
    } finally {
      event.target.value = "";
    }
  });
  reader.readAsText(file);
}

function download(filename, type, content) {
  const blob = new Blob([content], { type });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
}

function setMessage(message, isError = false) {
  elements.formMessage.textContent = message;
  elements.formMessage.style.color = isError ? "var(--red)" : "var(--muted)";
  if (message) showToast(message, isError ? "error" : "success");
}

function showToast(message, type = "success", options = {}) {
  if (!elements.toastStack || !message) return;
  const toast = document.createElement("div");
  toast.className = `toast ${type}`;
  const text = document.createElement("span");
  text.textContent = message;
  toast.appendChild(text);
  if (options.actionLabel && typeof options.onAction === "function") {
    const action = document.createElement("button");
    action.type = "button";
    action.className = "toast-action";
    action.textContent = options.actionLabel;
    action.addEventListener("click", () => {
      toast.remove();
      options.onAction();
    });
    toast.appendChild(action);
  }
  elements.toastStack.appendChild(toast);
  window.setTimeout(() => {
    toast.remove();
  }, options.duration || 3200);
}

function initTheme() {
  const stored = localStorage.getItem(THEME_KEY);
  const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
  applyTheme(stored || (prefersDark ? "dark" : "light"));
}

function applyTheme(theme) {
  const isDark = theme === "dark";
  if (isDark) {
    document.documentElement.dataset.theme = "dark";
  } else {
    delete document.documentElement.dataset.theme;
  }
  localStorage.setItem(THEME_KEY, isDark ? "dark" : "light");
  if (elements.themeToggleBtn) {
    elements.themeToggleBtn.innerHTML = isDark ? ICON_SUN : ICON_MOON;
    elements.themeToggleBtn.title = isDark ? "Switch to light mode" : "Toggle dark mode";
    elements.themeToggleBtn.setAttribute("aria-label", elements.themeToggleBtn.title);
  }
  const meta = document.querySelector('meta[name="theme-color"]');
  if (meta) meta.content = isDark ? "#121212" : "#F9F9F9";
}

function toggleTheme() {
  const isDark = document.documentElement.dataset.theme === "dark";
  applyTheme(isDark ? "light" : "dark");
}

function chartColorForCategory(row, index) {
  const palette = groupChartColors[row.group] || groupChartColors.Needs;
  return palette[index % palette.length];
}

function populateEditCategorySelect(type = elements.editTypeInput.value, selected = "") {
  const categories = state.categories.filter((category) => category.type === type);
  elements.editCategoryInput.innerHTML = categories
    .map((category) => `<option>${escapeHtml(category.name)}</option>`)
    .join("");
  if (selected && categories.some((category) => category.name === selected)) {
    elements.editCategoryInput.value = selected;
  }
}

function openEditDialog(id) {
  const item = state.transactions.find((transaction) => transaction.id === id);
  if (!item) return;
  editingTransactionId = id;
  elements.editDateInput.value = item.date;
  elements.editTypeInput.value = item.type;
  populateEditCategorySelect(item.type, item.category);
  elements.editAccountInput.value = item.account;
  elements.editDescriptionInput.value = item.description;
  elements.editAmountInput.value = item.amount;
  elements.editDialog.hidden = false;
  document.body.classList.add("wizard-open");
  elements.editDateInput.focus();
}

function closeEditDialog() {
  editingTransactionId = null;
  elements.editDialog.hidden = true;
  syncOverlayBodyClass();
}

function saveEditTransaction(event) {
  event.preventDefault();
  const item = state.transactions.find((transaction) => transaction.id === editingTransactionId);
  if (!item) return;

  const dateCheck = validateDate(elements.editDateInput.value);
  const amountCheck = validateAmount(elements.editAmountInput.value);
  const typeCheck = validateTransactionType(elements.editTypeInput.value);
  const categoryCheck = validateCategoryName(elements.editCategoryInput.value);
  const descriptionCheck = validateDescription(elements.editDescriptionInput.value);
  if (!dateCheck.ok || !amountCheck.ok || !typeCheck.ok || !categoryCheck.ok || !descriptionCheck.ok) {
    showToast(
      dateCheck.message || amountCheck.message || typeCheck.message || categoryCheck.message || descriptionCheck.message,
      "error",
    );
    return;
  }

  item.date = dateCheck.value;
  item.type = typeCheck.value;
  item.category = categoryCheck.value;
  item.account = elements.editAccountInput.value;
  item.description = descriptionCheck.value || categoryCheck.value;
  item.amount = amountCheck.value;
  saveState();
  closeEditDialog();
  render();
  showToast("Transaction updated.");
}

function installGlobalKeyboard() {
  document.addEventListener("keydown", (event) => {
    if (event.key === "Tab" && !elements.setupWizard.hidden) {
      trapFocus(event, elements.setupWizard);
      return;
    }
    if (event.key !== "Escape") return;
    if (elements.payScheduleDialog && !elements.payScheduleDialog.hidden) {
      event.preventDefault();
      closePayScheduleDialog();
      return;
    }
    if (elements.budgetsDialog && !elements.budgetsDialog.hidden) {
      event.preventDefault();
      closeBudgetsDialog();
      return;
    }
    if (!elements.editDialog.hidden) {
      event.preventDefault();
      closeEditDialog();
      return;
    }
    if (!elements.setupWizard.hidden) {
      event.preventDefault();
      closeWizard();
      return;
    }
    if (
      activeTab === "settings" &&
      elements.setupWizard.hidden &&
      elements.editDialog.hidden &&
      (!elements.payScheduleDialog || elements.payScheduleDialog.hidden) &&
      (!elements.budgetsDialog || elements.budgetsDialog.hidden)
    ) {
      event.preventDefault();
      closeSettingsView();
    }
  });
}

function focusWizardStep() {
  const step = elements.setupWizard.querySelector(".wizard-step:not([hidden])");
  const focusable = step?.querySelector("button, input, select, textarea, [tabindex]:not([tabindex='-1'])");
  focusable?.focus();
}

function trapFocus(event, container) {
  const focusable = [...container.querySelectorAll("button, input, select, textarea, a[href], [tabindex]:not([tabindex='-1'])")].filter(
    (node) => !node.disabled && node.offsetParent !== null,
  );
  if (!focusable.length) return;
  const first = focusable[0];
  const last = focusable[focusable.length - 1];
  if (event.shiftKey && document.activeElement === first) {
    event.preventDefault();
    last.focus();
  } else if (!event.shiftKey && document.activeElement === last) {
    event.preventDefault();
    first.focus();
  }
}

function monthRange(selectedMonth, count) {
  const [year, month] = selectedMonth.split("-").map(Number);
  const end = new Date(year, month - 1, 1);
  const start = new Date(end);
  start.setMonth(start.getMonth() - count + 1);
  return Array.from({ length: count }, (_, index) => {
    const date = new Date(start);
    date.setMonth(start.getMonth() + index);
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}`;
  });
}

function monthlyIncomeFromPay(payAmount, frequencyId) {
  const multiplier = payFrequencies[frequencyId]?.monthlyMultiplier || 1;
  return Math.round((Number(payAmount) || 0) * multiplier);
}

function payAmountFromMonthly(monthlyIncome, frequencyId) {
  const multiplier = payFrequencies[frequencyId]?.monthlyMultiplier || 1;
  return Math.round((Number(monthlyIncome) || 0) / multiplier);
}

function nextDefaultPayDate(frequencyId) {
  const today = parseLocalDate(todayString());
  if (frequencyId === "monthly") {
    return toDateString(new Date(today.getFullYear(), today.getMonth() + 1, 1));
  }
  if (frequencyId === "semimonthly") {
    const day = today.getDate() < 15 ? 15 : 1;
    const monthOffset = today.getDate() < 15 ? 0 : 1;
    return toDateString(new Date(today.getFullYear(), today.getMonth() + monthOffset, day));
  }
  return toDateString(addDays(today, 7));
}

function getPayPeriodForDate(dateString, profileInput) {
  const profile = normalizeSetupProfile(profileInput);
  const reference = parseLocalDate(dateString);

  if (profile.payFrequency === "monthly") {
    const start = new Date(reference.getFullYear(), reference.getMonth(), 1);
    const end = new Date(reference.getFullYear(), reference.getMonth() + 1, 0);
    return { start: toDateString(start), end: toDateString(end) };
  }

  if (profile.payFrequency === "semimonthly") {
    const isFirstHalf = reference.getDate() <= 15;
    const start = new Date(reference.getFullYear(), reference.getMonth(), isFirstHalf ? 1 : 16);
    const end = new Date(reference.getFullYear(), reference.getMonth(), isFirstHalf ? 15 : new Date(reference.getFullYear(), reference.getMonth() + 1, 0).getDate());
    return { start: toDateString(start), end: toDateString(end) };
  }

  const interval = payFrequencies[profile.payFrequency]?.intervalDays || 14;
  let start = parseLocalDate(profile.nextPayDate || dateString);
  while (start > reference) {
    start = addDays(start, -interval);
  }
  while (addDays(start, interval) <= reference) {
    start = addDays(start, interval);
  }
  const end = addDays(start, interval - 1);
  return { start: toDateString(start), end: toDateString(end) };
}

function dateInRange(dateString, startString, endString) {
  return dateString >= startString && dateString <= endString;
}

function currentMonthKey() {
  return monthKeyFromDate(todayString());
}

function defaultDateForMonth(month) {
  const today = todayString();
  return monthKeyFromDate(today) === month ? today : `${month}-01`;
}

function todayString() {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, "0");
  const day = String(now.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function parseLocalDate(dateString) {
  const [year, month, day] = dateString.split("-").map(Number);
  return new Date(year, month - 1, day);
}

function addDays(date, days) {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
}

function toDateString(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function monthKeyFromDate(dateString) {
  return dateString.slice(0, 7);
}

function setSelectedMonth(monthKey) {
  const next = /^\d{4}-\d{2}$/.test(monthKey) ? monthKey : currentMonthKey();
  elements.monthInput.value = next;
  localStorage.setItem(SELECTED_MONTH_KEY, next);
  syncMonthLabel(next);
}

function syncMonthLabel(monthKey = elements.monthInput.value) {
  if (elements.monthLabel) {
    elements.monthLabel.textContent = formatMonthLabel(monthKey);
  }
}

function shiftMonth(delta) {
  const [year, month] = (elements.monthInput.value || currentMonthKey()).split("-").map(Number);
  const next = new Date(year, month - 1 + delta, 1);
  const nextKey = `${next.getFullYear()}-${String(next.getMonth() + 1).padStart(2, "0")}`;
  setSelectedMonth(nextKey);
  elements.dateInput.value = defaultDateForMonth(nextKey);
  render();
}

function formatMonthLabel(monthKey) {
  const [year, monthNumber] = monthKey.split("-").map(Number);
  return new Intl.DateTimeFormat("en-US", { month: "long", year: "numeric" }).format(
    new Date(year, monthNumber - 1, 1),
  );
}

function shortMonth(month) {
  const [year, monthNumber] = month.split("-").map(Number);
  return new Intl.DateTimeFormat("en-US", { month: "short", year: "2-digit" }).format(new Date(year, monthNumber - 1, 1));
}

function formatShortDate(dateString) {
  const [year, month, day] = dateString.split("-").map(Number);
  return new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric" }).format(
    new Date(year, month - 1, day),
  );
}

function formatPayPeriodRange(start, end) {
  const startParts = start.split("-").map(Number);
  const endParts = end.split("-").map(Number);
  const sameYear = startParts[0] === endParts[0];
  const left = formatShortDate(start);
  const right = sameYear
    ? formatShortDate(end)
    : new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric", year: "numeric" }).format(
        new Date(endParts[0], endParts[1] - 1, endParts[2]),
      );
  return `${left} – ${right}`;
}

function formatDate(dateString) {
  const [year, month, day] = dateString.split("-").map(Number);
  return new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric", year: "numeric" }).format(
    new Date(year, month - 1, day),
  );
}

function money(value) {
  return (value % 1 ? MONEY_CENTS_FORMAT : MONEY_WHOLE_FORMAT).format(value || 0);
}

function compactMoney(value) {
  return MONEY_COMPACT_FORMAT.format(value || 0);
}

function percent(value) {
  return PERCENT_FORMAT.format(value || 0);
}

function statusCopy(value) {
  if (value > 1) return "Over budget";
  if (value >= 0.85) return "Close watch";
  return "Healthy pace";
}

function sum(values) {
  return values.reduce((total, value) => total + Number(value || 0), 0);
}

function roundToNearest(value, increment) {
  return Math.round(value / increment) * increment;
}

function cleanCategoryName(value) {
  return String(value || "").trim().replace(/\s+/g, " ").slice(0, 40);
}

function categoryKey(value) {
  return cleanCategoryName(value).toLowerCase();
}

function categoryExists(categories, name) {
  const key = categoryKey(name);
  return categories.some((category) => categoryKey(category.name) === key);
}

function normalizeCategoryGroup(group) {
  return ["Needs", "Wants", "Savings"].includes(group) ? group : "Needs";
}

function groupRank(group) {
  return { Needs: 1, Wants: 2, Savings: 3, Income: 4 }[group] || 5;
}

function csvCell(value) {
  const text = String(value ?? "");
  return /[",\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
}

// escapeHtml is imported from security.js for all user-controlled HTML rendering.
