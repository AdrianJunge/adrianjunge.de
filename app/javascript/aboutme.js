function aboutTargetFromHash(hash) {
    if (!hash || hash === "#") return null;

    let targetId;
    try {
        targetId = decodeURIComponent(hash.slice(1));
    } catch (_error) {
        targetId = hash.slice(1);
    }

    return targetId ? document.getElementById(targetId) : null;
}

function openDetailsForTarget(target) {
    if (!target) return false;

    const details = [];
    let element = target;
    while (element) {
        if (element.matches && element.matches("details")) details.push(element);
        element = element.parentElement;
    }

    details.forEach((element) => {
        element.open = true;
    });

    return details.length > 0;
}

function scrollToAboutTarget(target, options = {}) {
    if (!target) return;

    window.requestAnimationFrame(() => {
        window.requestAnimationFrame(() => {
            target.scrollIntoView({
                behavior: options.behavior || "auto",
                block: "start",
            });
        });
    });
}

function revealAboutHashTarget(options = {}) {
    if (!document.querySelector(".aboutme-page")) return;

    const target = aboutTargetFromHash(window.location.hash);
    if (!target) return;

    openDetailsForTarget(target);

    if (options.scroll) {
        scrollToAboutTarget(target, options);
    }
}

function initializeAboutStatsNavigation() {
    if (!document.querySelector(".aboutme-page")) return;

    const links = document.querySelectorAll(".aboutme-page .aboutme-stats .aboutme-stat[href^='#']");

    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

    links.forEach((link) => {
        if (link.dataset.smoothScrollBound === "true") return;

        link.dataset.smoothScrollBound = "true";
        link.addEventListener("click", (event) => {
            const hash = link.getAttribute("href");
            const target = aboutTargetFromHash(hash);
            if (!target) return;

            event.preventDefault();
            openDetailsForTarget(target);
            scrollToAboutTarget(target, { behavior: reducedMotion.matches ? "auto" : "smooth" });

            if (window.location.hash !== hash) {
                history.pushState(null, "", hash);
            }
        });
    });

    window.requestAnimationFrame(() => {
        revealAboutHashTarget({ scroll: true, behavior: "auto" });
    });
}

document.addEventListener("DOMContentLoaded", initializeAboutStatsNavigation);
document.addEventListener("turbo:load", initializeAboutStatsNavigation);
window.addEventListener("hashchange", () => {
    revealAboutHashTarget({ scroll: true, behavior: "auto" });
});
