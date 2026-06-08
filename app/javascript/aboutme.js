function initializeAboutStatsNavigation() {
    const links = document.querySelectorAll(".aboutme-page .aboutme-stats .aboutme-stat[href^='#']");
    if (!links.length) return;

    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

    links.forEach((link) => {
        if (link.dataset.smoothScrollBound === "true") return;

        link.dataset.smoothScrollBound = "true";
        link.addEventListener("click", (event) => {
            const hash = link.getAttribute("href");
            if (!hash || hash === "#") return;

            let targetId;
            try {
                targetId = decodeURIComponent(hash.slice(1));
            } catch (_error) {
                targetId = hash.slice(1);
            }

            const target = document.getElementById(targetId);
            if (!target) return;

            event.preventDefault();
            target.scrollIntoView({
                behavior: reducedMotion.matches ? "auto" : "smooth",
                block: "start",
            });

            if (window.location.hash !== hash) {
                history.pushState(null, "", hash);
            }
        });
    });
}

document.addEventListener("DOMContentLoaded", initializeAboutStatsNavigation);
document.addEventListener("turbo:load", initializeAboutStatsNavigation);
