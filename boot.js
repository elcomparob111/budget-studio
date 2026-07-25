/* Entry helpers that must stay external — CSP forbids inline scripts. */
(function () {
  var path = location.pathname || "";
  if (/\/budget-studio$/i.test(path)) {
    location.replace(path + "/" + location.search + location.hash);
    return;
  }

  if (!("serviceWorker" in navigator)) return;
  var swUrl = new URL("sw.js?v=80", location.href);
  navigator.serviceWorker
    .register(swUrl.href)
    .then(function (reg) {
      return reg.update();
    })
    .catch(function () {});

  var refreshing = false;
  navigator.serviceWorker.addEventListener("controllerchange", function () {
    if (refreshing || sessionStorage.getItem("bs-sw-reloaded-v80")) return;
    refreshing = true;
    sessionStorage.setItem("bs-sw-reloaded-v80", "1");
    location.reload();
  });
})();
