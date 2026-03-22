// Shared sidebar functionality - runs on all pages
function initSidebar() {
  const menuIcons = document.querySelectorAll(".menu-icon");
  const taskbarLeft = document.getElementById("taskbar-left");
  
  if (!menuIcons.length || !taskbarLeft) return;

  menuIcons.forEach(function(menuIcon) {
    menuIcon.addEventListener("click", function () {
      menuIcons.forEach(icon => icon.classList.toggle('shift'));
      taskbarLeft.classList.toggle("expanded");
      taskbarLeft.classList.toggle("collapsed");
    });
  });

  taskbarLeft.addEventListener('transitionend', function() {
    if (this.classList.contains('expanded')) {
      document.querySelectorAll('.taskbar-label').forEach(function(label) {
        label.style.whiteSpace = 'pre-wrap';
        label.style.opacity = '1';
      });
    }
  });

  taskbarLeft.addEventListener('transitionstart', function() {
    if (this.classList.contains('collapsed')) {
      document.querySelectorAll('.taskbar-label').forEach(function(label) {
        label.style.whiteSpace = 'nowrap';
        label.style.opacity = '0';
      });
    }
  });
}

// Initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initSidebar);
} else {
  initSidebar();
}
