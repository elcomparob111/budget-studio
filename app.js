import {
  initSync,
  signUp,
  signIn,
  signOutUser,
  resetPassword,
  updatePassword,
  isPasswordRecoveryLink,
  fetchCloudBudget,
  pushCloudBudget,
  friendlyAuthError,
} from "./sync.js";

const STORAGE_KEY = "budget-studio-state-v7";
const SELECTED_MONTH_KEY = "budget-studio-selected-month";
const THEME_KEY = "budget-studio-theme";
const PROFILES_KEY = "budget-studio-profiles";
const CLOUD_DIRTY_KEY = "budget-studio-cloud-dirty";

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
  incomeMetric: document.querySelector("#incomeMetric"),
  incomeSubtext: document.querySelector("#incomeSubtext"),
  spentMetric: document.querySelector("#spentMetric"),
  spentSubtext: document.querySelector("#spentSubtext"),
  leftMetric: document.querySelector("#leftMetric"),
  leftSubtext: document.querySelector("#leftSubtext"),
  budgetRing: document.querySelector("#budgetRing"),
  budgetUsedMetric: document.querySelector("#budgetUsedMetric"),
  ringSubtext: document.querySelector("#ringSubtext"),
  payPeriodBadge: document.querySelector("#payPeriodBadge"),
  payPeriodRange: document.querySelector("#payPeriodRange"),
  paycheckIncomeMetric: document.querySelector("#paycheckIncomeMetric"),
  paycheckSpentMetric: document.querySelector("#paycheckSpentMetric"),
  paycheckLeftMetric: document.querySelector("#paycheckLeftMetric"),
  paycheckBreakdown: document.querySelector("#paycheckBreakdown"),
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
  settingsTab: document.querySelector("#settingsTab"),
  tabBar: document.querySelector("#tabBar"),
  addTransactionBtn: document.querySelector("#addTransactionBtn"),
  exportCsvBtn: document.querySelector("#exportCsvBtn"),
  exportJsonBtn: document.querySelector("#exportJsonBtn"),
  importJsonInput: document.querySelector("#importJsonInput"),
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
  authSubmitBtn: document.querySelector("#authSubmitBtn"),
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
let state = createEmptyState();
let wizard = createWizardDraft(false);
let editingTransactionId = null;

init();

function init() {
  initTheme();
  elements.monthInput.value = localStorage.getItem(SELECTED_MONTH_KEY) || currentMonthKey();
  elements.dateInput.value = defaultDateForMonth(elements.monthInput.value);
  elements.accountInput.innerHTML = accounts.map((account) => `<option>${escapeHtml(account)}</option>`).join("");
  elements.editAccountInput.innerHTML = accounts.map((account) => `<option>${escapeHtml(account)}</option>`).join("");
  populateCategorySelect();
  attachEvents();
  installGlobalKeyboard();
  render();
  initSync(handleUserChanged).catch(() => handleUserChanged(null, { unavailable: true }));
  window.addEventListener("online", flushDirtyCloudSave);
}

async function handleUserChanged(user, info) {
  if (info?.unavailable) {
    // No cloud configured: behave like the previous local-only app
    localOnlyMode = true;
    currentUser = { uid: "local", displayName: legacyProfileName() || "" };
    state = loadState();
    populateCategorySelect();
    renderIdentityUI();
    render();
    if (!state.setupComplete) openWizard(false);
    return;
  }

  currentUser = user;
  if (!user) {
    state = createEmptyState();
    renderIdentityUI();
    render();
    openAuthGate();
    return;
  }

  // Password-recovery links sign the user in temporarily so they can set a new password.
  if (isPasswordRecoveryLink() || authMode === "recovery") {
    currentUser = user;
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

  try {
    const cloud = await fetchCloudBudget(user.uid);
    const local = readCachePayload(user.uid);
    if (cloud && (!local || (cloud.updatedAt || 0) > (local.updatedAt || 0))) {
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
    } else if (!cloud && local) {
      await pushCloudBudget(user.uid, { state: local.state, updatedAt: local.updatedAt || Date.now(), name: user.displayName || "" });
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
    showToast("Working offline — changes will sync when you're back online.", "error");
    localStorage.setItem(CLOUD_DIRTY_KEY, "1");
  }

  if (!state.setupComplete) {
    openWizard(false);
  }
}

function attachEvents() {
  elements.monthInput.addEventListener("change", () => {
    localStorage.setItem(SELECTED_MONTH_KEY, elements.monthInput.value);
    elements.dateInput.value = defaultDateForMonth(elements.monthInput.value);
    render();
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
    const amount = Number(elements.amountInput.value);
    if (!elements.dateInput.value || !Number.isFinite(amount) || amount <= 0) {
      setMessage("Enter a date and an amount greater than zero.", true);
      return;
    }

    const item = transaction(
      elements.dateInput.value,
      elements.typeInput.value,
      elements.categoryInput.value,
      elements.descriptionInput.value.trim() || elements.categoryInput.value,
      elements.accountInput.value,
      amount,
    );

    state.transactions.push(item);
    saveState();
    elements.descriptionInput.value = "";
    elements.amountInput.value = "";
    setMessage("Transaction added.");
    render();
  });

  elements.transactionsBody.addEventListener("click", (event) => {
    const deleteButton = event.target.closest("[data-delete-id]");
    if (deleteButton) {
      const id = deleteButton.dataset.deleteId;
      state.transactions = state.transactions.filter((item) => item.id !== id);
      saveState();
      render();
      showToast("Transaction deleted.");
      return;
    }

    const editButton = event.target.closest("[data-edit-id]");
    const row = event.target.closest("[data-transaction-id]");
    const id = editButton?.dataset.editId || row?.dataset.transactionId;
    if (id) openEditDialog(id);
  });

  elements.budgetEditor.addEventListener("change", (event) => {
    const input = event.target.closest("[data-budget-category]");
    if (!input) return;
    const category = state.categories.find((item) => item.name === input.dataset.budgetCategory);
    if (!category) return;
    category.budget = Math.max(0, Number(input.value) || 0);
    saveState();
    renderDashboard();
  });
  elements.categoryBuilderForm.addEventListener("submit", (event) => {
    event.preventDefault();
    addCategoryFromBudgetPanel();
  });
  elements.categoryBuilderAddBtn.addEventListener("click", (event) => {
    event.preventDefault();
    addCategoryFromBudgetPanel();
  });

  elements.resetBtn.addEventListener("click", () => openWizard(true));
  elements.openSetupBtn.addEventListener("click", () => switchTab("settings"));
  elements.closeSettingsBtn.addEventListener("click", () => switchTab("overview"));
  elements.tabBar?.addEventListener("click", (event) => {
    const button = event.target.closest("[data-tab]");
    if (button) switchTab(button.dataset.tab);
  });
  elements.addTransactionBtn?.addEventListener("click", () => {
    switchTab("activity");
    elements.amountInput?.focus();
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
  elements.exportJsonBtn.addEventListener("click", exportJson);
  elements.importJsonInput.addEventListener("change", importJson);

  elements.authForm.addEventListener("submit", handleAuthSubmit);
  elements.authModeToggleBtn.addEventListener("click", () => {
    setAuthMode(authMode === "signin" ? "signup" : "signin");
  });
  elements.authForgotBtn.addEventListener("click", handleForgotPassword);
  elements.signOutBtn.addEventListener("click", async () => {
    await signOutUser();
    showToast("Signed out.");
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
  activeTab = tab === "activity" || tab === "settings" ? tab : "overview";
  const panels = {
    overview: elements.overviewTab,
    activity: elements.activityTab,
    settings: elements.settingsTab,
  };
  Object.entries(panels).forEach(([name, panel]) => {
    if (panel) panel.hidden = name !== activeTab;
  });
  elements.tabBar?.querySelectorAll("[data-tab]").forEach((button) => {
    const selected = button.dataset.tab === activeTab;
    button.classList.toggle("is-active", selected);
    if (selected) button.setAttribute("aria-current", "page");
    else button.removeAttribute("aria-current");
  });
  renderIdentityUI();
  window.scrollTo({ top: 0, behavior: "smooth" });
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
  // First-time setup starts with an empty ledger; re-running setup keeps existing rows.
  const existingTransactions = state.setupComplete ? state.transactions : [];

  state = {
    categories: finalCategories,
    transactions: existingTransactions,
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
  const name = cleanCategoryName(elements.customCategoryNameInput.value);
  if (!name) {
    setCustomCategoryMessage("Type a category name first.", true);
    return;
  }

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
  renderDashboard();
  renderTransactions();
  renderBudgetEditor();
}

function renderDashboard() {
  const month = elements.monthInput.value;
  const summary = getMonthSummary(month);
  const usedPercent = summary.totalBudget ? summary.expenses / summary.totalBudget : 0;
  const left = summary.totalBudget - summary.expenses;
  const net = summary.income - summary.expenses;
  const savingsRate = summary.income ? net / summary.income : 0;
  const topCategory = summary.categoryRows.find((row) => row.spent > 0);

  elements.incomeMetric.textContent = money(summary.income);
  elements.incomeSubtext.textContent = `${summary.incomeCount} income ${summary.incomeCount === 1 ? "item" : "items"}`;
  elements.spentMetric.textContent = money(summary.expenses);
  elements.spentSubtext.textContent = `${percent(usedPercent)} of ${money(summary.totalBudget)}`;
  elements.leftMetric.textContent = money(left);
  elements.leftSubtext.textContent = left >= 0 ? "Available this month" : "Over planned budget";
  elements.budgetUsedMetric.textContent = percent(usedPercent);
  elements.budgetRing.style.setProperty("--used", `${Math.min(100, Math.max(0, usedPercent * 100))}%`);
  elements.budgetRing.classList.toggle("over", usedPercent > 1);
  elements.ringSubtext.textContent = statusCopy(usedPercent);
  elements.netMetric.textContent = `${money(net)} net`;
  elements.netMetric.className = "money-chip";
  elements.savingsMetric.textContent = `${percent(savingsRate)} saved`;
  elements.savingsMetric.className = "money-chip";
  elements.topCategoryBadge.textContent = topCategory ? `${topCategory.name}: ${money(topCategory.spent)}` : "No spending yet";

  renderProgress(summary.categoryRows);
  renderBarChart(summary.categoryRows);
  renderTrendChart(month);
  renderPaycheckView(month);
}

function renderPaycheckView(month) {
  const paySummary = getPayPeriodSummary(month);
  elements.payPeriodBadge.textContent = paySummary.label;
  elements.payPeriodRange.textContent = paySummary.rangeLabel;
  elements.paycheckIncomeMetric.textContent = money(paySummary.income);
  elements.paycheckSpentMetric.textContent = money(paySummary.expenses);
  const paycheckLeft = paySummary.income - paySummary.expenses;
  elements.paycheckLeftMetric.textContent = money(paycheckLeft);

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
  const visible = rows.slice(0, 9);
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
    <svg viewBox="0 0 ${width} ${height}" role="img" aria-label="Spending by category">
      <style>
        .svg-label { fill: #334155; font: 700 13px system-ui; }
        .svg-value { fill: #64748b; font: 800 12px system-ui; }
      </style>
      ${rowsSvg}
    </svg>
  `;
}

function renderTrendChart(selectedMonth) {
  const months = monthRange(selectedMonth, 11);
  const points = months.map((month) => {
    const summary = getMonthSummary(month);
    return {
      month,
      label: shortMonth(month),
      income: summary.income,
      expenses: summary.expenses,
      net: summary.income - summary.expenses,
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
        <line x1="${padding.left}" x2="${width - padding.right}" y1="${lineY}" y2="${lineY}" stroke="#e2e8f0" />
        <text x="8" y="${lineY + 4}" class="axis">${compactMoney(value)}</text>
      `;
    })
    .join("");
  const labels = points
    .map((point, index) => `<text x="${x(index)}" y="${height - 14}" text-anchor="middle" class="axis">${point.label}</text>`)
    .join("");

  elements.trendChart.innerHTML = `
    <svg viewBox="0 0 ${width} ${height}" role="img" aria-label="Income, spending, and cash flow trend">
      <style>
        .axis { fill: #64748b; font: 700 11px system-ui; }
        .legend { fill: #334155; font: 800 12px system-ui; }
      </style>
      ${grid}
      <line x1="${padding.left}" x2="${width - padding.right}" y1="${y(0)}" y2="${y(0)}" stroke="#94a3b8" />
      <path d="${pathFor("income")}" fill="none" stroke="#16a34a" stroke-width="3" stroke-linecap="round" />
      <path d="${pathFor("expenses")}" fill="none" stroke="#dc2626" stroke-width="3" stroke-linecap="round" />
      <path d="${pathFor("net")}" fill="none" stroke="#2563eb" stroke-width="3" stroke-linecap="round" />
      ${labels}
      <circle cx="610" cy="18" r="5" fill="#16a34a"></circle><text x="620" y="22" class="legend">Income</text>
      <circle cx="690" cy="18" r="5" fill="#dc2626"></circle><text x="700" y="22" class="legend">Spent</text>
      <circle cx="760" cy="18" r="5" fill="#2563eb"></circle><text x="770" y="22" class="legend">Net</text>
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
    elements.transactionsBody.innerHTML = `
      <tr>
        <td colspan="7">No transactions match this month and filter.</td>
      </tr>
    `;
    return;
  }

  elements.transactionsBody.innerHTML = rows
    .map(
      (item) => `
        <tr class="table-row-clickable" data-transaction-id="${item.id}">
          <td>${formatDate(item.date)}</td>
          <td><span class="type-pill ${item.type.toLowerCase()}">${escapeHtml(item.type)}</span></td>
          <td>${escapeHtml(item.category)}</td>
          <td>${escapeHtml(item.description)}</td>
          <td>${escapeHtml(item.account)}</td>
          <td class="amount">${money(item.amount)}</td>
          <td class="action-cell">
            <button class="edit-button" data-edit-id="${item.id}" type="button">Edit</button>
            <button class="delete-button" data-delete-id="${item.id}" type="button">Delete</button>
          </td>
        </tr>
      `,
    )
    .join("");
}

function renderBudgetEditor() {
  elements.budgetEditor.innerHTML = state.categories
    .filter((category) => category.type === "Expense")
    .map(
      (category) => `
        <label class="budget-item">
          <strong>${escapeHtml(category.name)}</strong>
          <small>${escapeHtml(category.group)}</small>
          <input
            type="number"
            min="0"
            step="10"
            value="${category.budget}"
            data-budget-category="${escapeHtml(category.name)}"
            aria-label="${escapeHtml(category.name)} monthly budget"
          />
        </label>
      `,
    )
    .join("");
}

function addCategoryFromBudgetPanel() {
  const name = cleanCategoryName(elements.categoryBuilderNameInput.value);
  if (!name) {
    setCategoryBuilderMessage("Type a category name first.", true);
    return;
  }

  if (categoryExists(state.categories, name)) {
    setCategoryBuilderMessage(`${name} already exists. Update its budget above.`, true);
    return;
  }

  state.categories.push({
    name,
    type: "Expense",
    group: normalizeCategoryGroup(elements.categoryBuilderGroupInput.value),
    budget: Math.max(0, Number(elements.categoryBuilderBudgetInput.value) || 0),
  });
  saveState();
  populateCategorySelect();
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

function getMonthSummary(month) {
  const monthTransactions = state.transactions.filter((item) => monthKeyFromDate(item.date) === month);
  const incomeItems = monthTransactions.filter((item) => item.type === "Income");
  const expenseItems = monthTransactions.filter((item) => item.type === "Expense");
  const income = sum(incomeItems.map((item) => item.amount));
  const expenses = sum(expenseItems.map((item) => item.amount));
  const expenseCategories = state.categories.filter((category) => category.type === "Expense");
  const totalBudget = sum(expenseCategories.map((category) => category.budget));
  const categoryRows = expenseCategories
    .map((category) => {
      const spent = sum(expenseItems.filter((item) => item.category === category.name).map((item) => item.amount));
      return {
        ...category,
        spent,
        left: category.budget - spent,
      };
    })
    .sort((a, b) => b.spent - a.spent || b.budget - a.budget);

  return {
    monthTransactions,
    income,
    expenses,
    totalBudget,
    incomeCount: incomeItems.length,
    expenseCount: expenseItems.length,
    categoryRows,
  };
}

function getPayPeriodSummary(month) {
  const profile = normalizeSetupProfile(state.setupProfile);
  const referenceDate = month === currentMonthKey() ? todayString() : `${month}-01`;
  const period = getPayPeriodForDate(referenceDate, profile);
  const periodTransactions = state.transactions.filter((item) => dateInRange(item.date, period.start, period.end));
  const incomeItems = periodTransactions.filter((item) => item.type === "Income");
  const expenseItems = periodTransactions.filter((item) => item.type === "Expense");
  const actualIncome = sum(incomeItems.map((item) => item.amount));
  const income = actualIncome || profile.payAmount || 0;
  const expenses = sum(expenseItems.map((item) => item.amount));
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
    rangeLabel: `${formatDate(period.start)} - ${formatDate(period.end)}`,
    income,
    expenses,
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
    setupComplete: false,
    setupProfile: null,
  };
}

function createDemoState() {
  return {
    categories: structuredClone(defaultCategories),
    transactions: structuredClone(defaultTransactions),
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
  const setupProfile = raw.setupProfile ? normalizeSetupProfile(raw.setupProfile) : null;
  const transactions = stripAutoGeneratedPaychecks(raw.transactions || []);
  return {
    ...raw,
    transactions,
    setupComplete: raw.setupComplete ?? true,
    setupProfile,
  };
}

function openAuthGate() {
  setAuthMode("signin");
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

  elements.authTitle.textContent = recovery
    ? "Choose a new password"
    : signup
      ? "Create your account"
      : "Welcome back";
  elements.authCopy.textContent = recovery
    ? "Enter a new password for your Budget Studio account. At least 6 characters."
    : "Sign in and your budget follows you on every device — private to your account only.";

  elements.authNameLabel.hidden = !signup;
  elements.authNameInput.required = signup;
  elements.authEmailLabel.hidden = recovery;
  elements.authEmailInput.required = !recovery;
  elements.authPasswordLabelText.textContent = recovery ? "New password" : "Password";
  elements.authPasswordInput.placeholder = recovery ? "New password (at least 6 characters)" : "At least 6 characters";
  elements.authPasswordInput.autocomplete = signup || recovery ? "new-password" : "current-password";
  elements.authSubmitBtn.textContent = recovery ? "Save new password" : signup ? "Create account" : "Sign in";
  elements.authModeToggleBtn.hidden = recovery;
  elements.authForgotBtn.hidden = signup || recovery;
  elements.authModeToggleBtn.textContent = signup ? "Already have an account? Sign in" : "New here? Create an account";
  setAuthMessage("");
}

async function handleForgotPassword() {
  const email = elements.authEmailInput.value.trim();
  if (!email) {
    setAuthMessage("Enter your email first, then tap Forgot password.", true);
    elements.authEmailInput.focus();
    return;
  }
  elements.authForgotBtn.disabled = true;
  setAuthMessage("Sending reset email...");
  try {
    await resetPassword(email);
    setAuthMessage("Check your email for a reset link. If nothing arrives in a minute, check spam.");
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
  const email = elements.authEmailInput.value.trim();
  const password = elements.authPasswordInput.value;
  const name = cleanProfileName(elements.authNameInput.value);

  if (authMode === "recovery") {
    if (password.length < 6) {
      setAuthMessage("Password needs at least 6 characters.", true);
      return;
    }
    elements.authSubmitBtn.disabled = true;
    setAuthMessage("Saving new password...");
    try {
      await updatePassword(password);
      elements.authPasswordInput.value = "";
      history.replaceState(null, "", window.location.pathname);
      setAuthMode("signin");
      setAuthMessage("Password updated. You're signed in.");
      showToast("Password updated.");
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

  elements.authSubmitBtn.disabled = true;
  setAuthMessage(authMode === "signup" ? "Creating your account..." : "Signing in...");
  try {
    if (authMode === "signup") {
      await signUp(name, email, password);
    } else {
      await signIn(email, password);
    }
    elements.authPasswordInput.value = "";
    // onAuthStateChanged drives the rest
  } catch (error) {
    setAuthMessage(friendlyAuthError(error), true);
  } finally {
    elements.authSubmitBtn.disabled = false;
  }
}

function renderIdentityUI() {
  const name = currentUser?.displayName ? cleanProfileName(currentUser.displayName) : "";
  const titles = {
    overview: name ? `${name}'s budget` : "Overview",
    activity: "Activity",
    settings: "Settings",
  };
  elements.appTitle.textContent = titles[activeTab] || titles.overview;
  elements.signOutBtn.hidden = localOnlyMode || !currentUser;
  if (elements.tabBar) elements.tabBar.hidden = Boolean(elements.authGate && !elements.authGate.hidden);
}

function flushDirtyCloudSave() {
  if (localOnlyMode || !currentUser || !localStorage.getItem(CLOUD_DIRTY_KEY)) return;
  const payload = readCachePayload(currentUser.uid);
  if (!payload) {
    localStorage.removeItem(CLOUD_DIRTY_KEY);
    return;
  }
  pushCloudBudget(currentUser.uid, { ...payload, name: currentUser.displayName || "" })
    .then(() => localStorage.removeItem(CLOUD_DIRTY_KEY))
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
  if (localOnlyMode) {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    } catch {
      showToast("Storage full — export a backup and clear old data.", "error");
    }
    return;
  }

  const payload = { state, updatedAt: Date.now(), name: currentUser.displayName || "" };
  writeCachePayload(currentUser.uid, payload);
  clearTimeout(cloudSaveTimer);
  cloudSaveTimer = setTimeout(() => {
    pushCloudBudget(currentUser.uid, payload)
      .then(() => localStorage.removeItem(CLOUD_DIRTY_KEY))
      .catch(() => localStorage.setItem(CLOUD_DIRTY_KEY, "1"));
  }, 700);
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

function importJson(event) {
  const [file] = event.target.files;
  if (!file) return;
  const reader = new FileReader();
  reader.addEventListener("load", () => {
    try {
      const imported = JSON.parse(String(reader.result));
      if (!Array.isArray(imported.categories) || !Array.isArray(imported.transactions)) {
        throw new Error("Invalid backup format.");
      }
      state = {
        ...imported,
        setupComplete: imported.setupComplete ?? true,
        setupProfile: imported.setupProfile ?? null,
      };
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

function showToast(message, type = "success") {
  if (!elements.toastStack || !message) return;
  const toast = document.createElement("div");
  toast.className = `toast ${type}`;
  toast.textContent = message;
  elements.toastStack.appendChild(toast);
  window.setTimeout(() => {
    toast.remove();
  }, 3200);
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
    elements.themeToggleBtn.textContent = isDark ? "☀" : "◐";
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
  if (elements.setupWizard.hidden) {
    document.body.classList.remove("wizard-open");
  }
}

function saveEditTransaction(event) {
  event.preventDefault();
  const item = state.transactions.find((transaction) => transaction.id === editingTransactionId);
  if (!item) return;

  const amount = Number(elements.editAmountInput.value);
  if (!elements.editDateInput.value || !Number.isFinite(amount) || amount <= 0) {
    showToast("Enter a date and an amount greater than zero.", "error");
    return;
  }

  item.date = elements.editDateInput.value;
  item.type = elements.editTypeInput.value;
  item.category = elements.editCategoryInput.value;
  item.account = elements.editAccountInput.value;
  item.description = elements.editDescriptionInput.value.trim() || item.category;
  item.amount = amount;
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
    if (activeTab === "settings" && elements.setupWizard.hidden && elements.editDialog.hidden) {
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

function getPaydaysForMonth(month, profileInput) {
  const profile = normalizeSetupProfile(profileInput);
  const monthStart = parseLocalDate(`${month}-01`);
  const monthEnd = new Date(monthStart.getFullYear(), monthStart.getMonth() + 1, 0);

  if (profile.payFrequency === "monthly") {
    const preferredDay = parseLocalDate(profile.nextPayDate).getDate();
    const payday = new Date(monthStart.getFullYear(), monthStart.getMonth(), Math.min(preferredDay, monthEnd.getDate()));
    return [toDateString(payday)];
  }

  if (profile.payFrequency === "semimonthly") {
    return [1, 15]
      .map((day) => new Date(monthStart.getFullYear(), monthStart.getMonth(), Math.min(day, monthEnd.getDate())))
      .map(toDateString);
  }

  const interval = payFrequencies[profile.payFrequency]?.intervalDays || 14;
  let cursor = parseLocalDate(profile.nextPayDate);
  while (cursor > monthStart) {
    cursor = addDays(cursor, -interval);
  }
  while (cursor < monthStart) {
    cursor = addDays(cursor, interval);
  }

  const paydays = [];
  while (cursor <= monthEnd) {
    paydays.push(toDateString(cursor));
    cursor = addDays(cursor, interval);
  }
  return paydays;
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

function shortMonth(month) {
  const [year, monthNumber] = month.split("-").map(Number);
  return new Intl.DateTimeFormat("en-US", { month: "short", year: "2-digit" }).format(new Date(year, monthNumber - 1, 1));
}

function formatDate(dateString) {
  const [year, month, day] = dateString.split("-").map(Number);
  return new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric", year: "numeric" }).format(
    new Date(year, month - 1, day),
  );
}

function money(value) {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: value % 1 ? 2 : 0,
  }).format(value || 0);
}

function compactMoney(value) {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    notation: "compact",
    maximumFractionDigits: 1,
  }).format(value || 0);
}

function percent(value) {
  return new Intl.NumberFormat("en-US", { style: "percent", maximumFractionDigits: 0 }).format(value || 0);
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

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}
