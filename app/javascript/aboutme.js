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
    const cardDetails = target.closest('.profile-card')?.querySelector(':scope > .profile-card-details');
    if (cardDetails) details.push(cardDetails);
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

function aboutScrollTargetFor(target) {
    return target.closest(".aboutme-card") || target.closest(".aboutme-section") || target;
}

function aboutTopScrollOffset() {
    const taskbar = document.getElementById("top-taskbar") || document.querySelector(".top-taskbar");
    const taskbarBottom = taskbar ? taskbar.getBoundingClientRect().bottom : 0;
    const configuredHeight = parseFloat(
        window.getComputedStyle(document.documentElement).getPropertyValue("--top-taskbar-height")
    ) || 0;

    return Math.max(taskbarBottom, configuredHeight) + 16;
}

function performAboutTargetScroll(target, options = {}) {
    const scrollTarget = aboutScrollTargetFor(target);
    const targetTop = window.scrollY + scrollTarget.getBoundingClientRect().top - aboutTopScrollOffset();

    window.scrollTo({
        top: Math.max(targetTop, 0),
        behavior: options.behavior || "auto",
    });
}

function scrollToAboutTarget(target, options = {}) {
    if (!target) return;

    performAboutTargetScroll(target, options);

    window.requestAnimationFrame(() => {
        window.requestAnimationFrame(() => {
            performAboutTargetScroll(target, options);
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

function revealAboutHashTargetAfterLoad() {
    if (!window.location.hash || window.__aboutHashLoadRevealBound === true) return;

    window.__aboutHashLoadRevealBound = true;

    const reveal = () => {
        revealAboutHashTarget({ scroll: true, behavior: "auto" });
    };

    if (document.readyState === "complete") {
        window.setTimeout(reveal, 0);
    } else {
        window.addEventListener("load", reveal, { once: true });
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
    revealAboutHashTargetAfterLoad();
}

function initializeAboutCardDisclosures() {
    document.querySelectorAll('.aboutme-page .profile-card[data-card-disclosure]').forEach((card) => {
        if (card.dataset.disclosureBound === 'true') return;

        const details = card.querySelector(':scope > .profile-card-details');
        const summary = details?.querySelector(':scope > summary');
        if (!details || !summary) return;

        card.dataset.disclosureBound = 'true';
        let pointerStart = null;
        card.addEventListener('pointerdown', (event) => {
            if (event.target.closest('.profile-card') !== card) return;
            pointerStart = { x: event.clientX, y: event.clientY };
        });
        card.addEventListener('pointercancel', () => { pointerStart = null; });
        card.addEventListener('click', (event) => {
            const start = pointerStart;
            pointerStart = null;
            if (event.defaultPrevented || event.button !== 0 ||
                event.altKey || event.ctrlKey || event.metaKey || event.shiftKey) return;
            if (event.target.closest('.profile-card') !== card) return;
            if (event.target.closest('a, button, input, select, textarea, label, summary, audio, video, [role="button"], [role="link"], [contenteditable]:not([contenteditable="false"])')) return;

            // Native summaries and nested disclosures keep their own behavior.
            const enclosingDetails = event.target.closest('details');
            if (enclosingDetails && enclosingDetails !== details && card.contains(enclosingDetails)) return;

            // A drag/selection is a reading action, not a disclosure activation.
            const selection = window.getSelection();
            if (selection && !selection.isCollapsed) return;
            if (start && Math.hypot(event.clientX - start.x, event.clientY - start.y) > 8) return;

            const restoreFocus = details.open && details.contains(document.activeElement);
            details.open = !details.open;
            if (restoreFocus) summary.focus({ preventScroll: true });
        });
    });
}

const initializedAboutPages = new WeakSet();

function resetAboutCategoryDefaults() {
    document.querySelectorAll('.aboutme-page > details.aboutme-section').forEach((section) => {
        section.open = false;
    });
}

function initializeAboutPage() {
    const page = document.querySelector('.aboutme-page');
    if (!page) return;
    if (!initializedAboutPages.has(page)) {
        resetAboutCategoryDefaults();
        initializedAboutPages.add(page);
    }
    initializeAboutStatsNavigation();
    initializeAboutCardDisclosures();
}

if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initializeAboutPage);
else initializeAboutPage();
document.addEventListener('turbo:load', initializeAboutPage);
window.addEventListener('pageshow', (event) => {
    // History restores reuse the live DOM, including toggled native details,
    // without DOMContentLoaded. Reset categories only when entering the page.
    if (!event.persisted) return;
    resetAboutCategoryDefaults();
    revealAboutHashTarget({ scroll: true, behavior: 'auto' });
});
window.addEventListener("hashchange", () => {
    revealAboutHashTarget({ scroll: true, behavior: "auto" });
});
