import "xterm";
import "xterm-addon-fit";

const fastFetchInfo = `  _____                          _
 |  __ \\                        | |                               ____
 | |__) |   ___    __ _    ___  | |__      _ __ ___     ___      / __ \\
 |  _  /   / _ \\  / _\` |  / __| | '_ \\    | '_ \` _ \\   / _ \\    / / _\` |
 | | \\ \\  |  __/ | (_| | | (__  | | | |   | | | | | | |  __/   | | (_| |
 |_|  \\_\\  \\___|  \\__,_|  \\___| |_| |_|   |_| |_| |_|  \\___|    \\ \\__,_|
                                                                 \\____/
`
const aboutMe = `\tDiscord:\t${createHyperlink('Discord', 'https://discord.com/users/305624492221267968')}
\tGitHub:\t\t${createHyperlink('GitHub', 'https://github.com/AdrianJunge/')}
\tLinkedin:\t${createHyperlink('Linkedin', 'https://www.linkedin.com/in/adrian-junge-998a63296/')}
`

const firstHelp = `\tNavigation via taskbar, 'cd' command or listed hyperlinks
\tType 'help' for more...
`

function getTerminalFontSize() {
    const viewportSize = Math.min(window.innerWidth / 96, window.innerHeight / 48);
    return Math.round(Math.min(18, Math.max(13, viewportSize)));
}

const term = new Terminal({
    convertEol: true,
    cursorBlink: true,
    fontSize: getTerminalFontSize(),
    lineHeight: 1.25,
});
const fitAddon = new FitAddon.FitAddon();
term.loadAddon(fitAddon);

const terminalElement = document.getElementById('terminal-container');
const pathsArray = JSON.parse(terminalElement.dataset.terminalText).map(normalizePathEntry);
let linkTooltip = document.getElementById('terminal-link-tooltip');

let inputBuffer = '';
let terminalOpened = false;
const terminalOpenKey = 'terminal-open';
let pendingFit = null;

const COLORS = {
    reset: '\x1B[0m',
    red: '\x1B[31m',
    green: '\x1B[32m',
    yellow: '\x1B[33m',
    blue: '\x1B[34m',
    magenta: '\x1B[35m',
    cyan: '\x1B[36m',
    white: '\x1B[37m',
    bold: '\x1B[1m',
    brightRed: '\x1B[38;2;255;70;70m',
    brightBlue: '\x1B[38;2;85;170;255m',
};

function wrapText(text, maxWidth) {
    const words = text.split(' ');
    let line = '';
    let wrappedText = '';

    words.forEach(word => {
        if ((line + word).length > maxWidth) {
            wrappedText += line + '\n' + '\t';
            line = '';
        } else if (word.includes('\n')) {
            wrappedText += line;
            line = '';
        }
        line += word + ' ';
    });

    wrappedText += line;
    return wrappedText;
}

function printMultiLineString(str = fastFetchInfo, color = COLORS.white, wrap = false) {
    if (wrap) {
        const maxTerminalWidth = term.cols;
        const wrappedText = wrapText(str, maxTerminalWidth);

        wrappedText.split('\n').forEach((line) => {
            term.writeln(colorize(colorize(line, color), COLORS.bold));
        });
    } else {
        const lines = str.split('\n');
        lines.forEach((line) => {
            term.writeln(colorize(colorize(line, color), COLORS.bold));
        });
    }
}

function colorize(text, color) {
    return color + text + COLORS.reset;
}

function printLine(text, color=COLORS.blue) {
    term.write(colorize(text, color));
}

function createHyperlink(text, url) {
    return `\x1b]8;;${url}\x07${text}\x1b]8;;\x07`
}

function normalizePathEntry(entry) {
    if (typeof entry === 'string') {
        return { label: entry, url: null, description: null };
    }

    return {
        label: String(entry.label || entry.path || ''),
        url: entry.url || null,
        description: entry.description || null,
    };
}

const customLinkHandler = {
  allowNonHttpProtocols: false,

  activate: (event, uri) => {
    event.preventDefault();
    const url = new URL(uri, window.location.origin);
    const isExternal = url.origin !== window.location.origin;

    if (isExternal) {
      window.open(uri, '_blank', 'noopener,noreferrer');
    } else {
      window.location.href = uri;
    }
  },
  hover: (event, uri) => {
    if (!linkTooltip) return;
    const rect = document
        .getElementById("terminal-container")
        .getBoundingClientRect();
    linkTooltip.textContent = uri;
    linkTooltip.style.visibility = "visible";
    linkTooltip.style.left = event.clientX - rect.left + 30 + "px";
    linkTooltip.style.top  = event.clientY - rect.top + "px";
  },
  leave: () => {
    if (linkTooltip) linkTooltip.style.visibility = "hidden";
  }
};


function typeText(text, color, callback) {
    let i = 0;
    function typeChar() {
        if (i >= text.length) {
            if (callback) callback();
            return;
        }
        printLine(text.charAt(i), color);
        i++;
        const delay = 25 + Math.random() * 100;
        setTimeout(typeChar, delay);
    }
    typeChar();
}


function getTargetUrl(pathEntry) {
    const entry = normalizePathEntry(pathEntry);
    const path = entry.label;

    if (entry.url) {
        return new URL(entry.url, window.location.origin).href;
    }

    let url;
    if (path === '~') {
        url = window.location.origin;
    } else if (path === '.') {
        url = window.location.href;
    } else if (path === '..') {
        url = window.location.origin + window.location.pathname.split('/').slice(0, -1).join('/');
    } else {
        url = window.location.href.endsWith("/") ? window.location.href + path : window.location.href + "/" + path;
    }

    return url;
}

function processCommand(command) {
    if (/^ls\s*(-[a-zA-Z]+)?\s*$/.test(command)) {
        generateLsOutput(pathsArray);
    } else if (/^cd\s+([^<>:"|?*\r\n]+)?\s*$/.test(command)) {
        const target = command.substring(3).trim();
        const targetEntry = pathsArray.find(entry => entry.label === target);
        if (targetEntry) {
            const targetUrl = getTargetUrl(targetEntry);
            printLine(`\n  Changing to ${target}...\n`);
            window.location.href = targetUrl;
            return;
        } else {
            printLine(`\n  Directory "${target}" not found.`, COLORS.white);
        }
    } else if (command === 'clear') {
        term.clear();
    } else if (command === 'whoami') {
        printLine('\n\tadrian\n\n', COLORS.white);
        printMultiLineString(aboutMe, COLORS.bold);
    } else if (command === 'help') {
        printLine('\n  Available commands:');
        printLine('\n\t- help: Shows this help message');
        printLine('\n\t- ls: Lists the directories');
        printLine('\n\t- cd <directory>: Navigates to a directory');
        printLine('\n\t- clear: Clears the terminal');
        printLine('\n\t- whoami: Who am I?');
    } else {
        printLine(`\n  Command not recognized: ${command}`, COLORS.white);
    }
    printLine(`\nadrian@my-space:~$ `, COLORS.brightRed);
}

function initializeTerminal() {
    terminalOpened = true;

    term.open(terminalElement);
    term.options.linkHandler = customLinkHandler;

    fitTerminal();

    if (window.location.pathname === '/') {
        printMultiLineString(fastFetchInfo, COLORS.brightBlue);
        printMultiLineString(aboutMe, COLORS.bold);
        printMultiLineString(firstHelp, COLORS.bold, true);
    }

    printLine('adrian@my-space:~$ ', COLORS.brightRed);
    typeText('ls -lah ~', COLORS.white, () => {
        generateLsOutput(pathsArray);
        printLine('\nadrian@my-space:~$ ', COLORS.brightRed);
    });

    term.onData(function(data) {
        if (data === '\r' || data === '\n') {
            const command = inputBuffer.trim();
            processCommand(command);
            inputBuffer = '';
        } else if (data === '\x7f') {
            if (inputBuffer.length > 0) {
                inputBuffer = inputBuffer.slice(0, -1);
                const cursorBack = '\x1b[D';
                const eraseChar = '\x1b[P';
                term.write(cursorBack + eraseChar);
            }
        } else if (data === '\x15') {
            const clearBuffer = inputBuffer.length;
            if (clearBuffer > 0) {
                const cursorBack = `\x1b[${clearBuffer}D`;
                const clearText = `\x1b[0K`;
                term.write(cursorBack + clearText);
                inputBuffer = '';
            }
        } else {
            inputBuffer += data;
            term.write(data);
        }
    });
};

function fitTerminal() {
    if (!terminalOpened || terminalElement.classList.contains('terminal-minimized')) return;

    if (pendingFit) window.cancelAnimationFrame(pendingFit);
    pendingFit = window.requestAnimationFrame(() => {
        term.options.fontSize = getTerminalFontSize();
        fitAddon.fit();
        pendingFit = null;
    });
}

function getFormattedDate() {
    const now = new Date();
    const formatted = new Intl.DateTimeFormat('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      hour12: false
    }).format(now);
    return formatted.replace(',', '');
}

function generateLsOutput(pathsArray) {
    pathsArray.forEach(entry => {
        let pathDisplay = entry.label;
        let hyperlink = '';
        let url = '';
        url = getTargetUrl(entry);

        hyperlink = colorize(createHyperlink(pathDisplay, url), COLORS.bold);
        const description = entry.description;

        if (description) {
            printLine(`\n  drwxrwxr-x  5 adrian adrian  4.0K ${getFormattedDate()}  ${hyperlink}   (${description})`, COLORS.brightBlue);
        } else {
            printLine(`\n  drwxrwxr-x  5 adrian adrian  4.0K ${getFormattedDate()}  ${hyperlink}`, COLORS.brightBlue);
        }
    });
}

function openTerminal(terminal) {
    terminal.classList.toggle("terminal-minimized");
    const nowMinimized = terminal.classList.contains("terminal-minimized");

    try {
        localStorage.setItem(terminalOpenKey, (!nowMinimized).toString());
    } catch(e) {
        console.error("Error accessing localStorage:", e);
    }

    if (nowMinimized) {
        if (terminalOpened) term.blur();
    } else {
        if (!terminalOpened) initializeTerminal();
        fitTerminal();
        term.focus();
    }
}

function minimizeTerminal() {
    const minimizeButton = document.getElementById("minimize-terminal");
    const maximizeButton = document.getElementById("maximize-terminal");
	const closeButton = document.getElementById("close-terminal");
	const terminal = document.getElementById("terminal-container");
	const terminalTaskbarIcon = document.getElementById("terminal-taskbar-button");

    minimizeButton.addEventListener("click", function () {
        terminal.classList.add("terminal-minimized");
        try {
            localStorage.setItem(terminalOpenKey, 'false');
        } catch(e) {
            console.error("Error accessing localStorage:", e);
        }
        if (terminalOpened) term.blur();
    });
    maximizeButton.addEventListener("click", function () {
        terminal.classList.toggle("terminal-maximized");
        if (terminalOpened) fitTerminal();
    });
    closeButton.addEventListener("click", function () {
        terminal.classList.add("terminal-minimized");
        try {
            localStorage.setItem(terminalOpenKey, 'false');
        } catch(e) {
            console.error("Error accessing localStorage:", e);
        }
        if (terminalOpened) term.blur();
    });
    terminalTaskbarIcon.addEventListener("click", function () {
        openTerminal(terminal);
    });
    terminal.addEventListener("wheel", function (event) {
        if (!terminal.classList.contains("terminal-minimized")) event.stopPropagation();
    }, { passive: true });
    terminal.addEventListener("touchmove", function (event) {
        if (!terminal.classList.contains("terminal-minimized")) event.stopPropagation();
    }, { passive: true });

    let isProcessingShortcut = false;
    const handleCtrlEnter = () => {
        if (isProcessingShortcut) return;
        isProcessingShortcut = true;

        openTerminal(terminal);

        setTimeout(() => {
            isProcessingShortcut = false;
        }, 200);
    };

    term.attachCustomKeyEventHandler((event) => {
        if (event.ctrlKey && event.key === 'Enter') {
            event.preventDefault();
            event.stopImmediatePropagation();
            handleCtrlEnter();
            return false;
        }
        return true;
    });

    document.addEventListener("keydown", (event) => {
        if (event.ctrlKey && event.key === "Enter") {
            event.preventDefault();
            event.stopImmediatePropagation();
            handleCtrlEnter();
        }
    });
}

document.addEventListener('DOMContentLoaded', function() {
    minimizeTerminal();
    window.addEventListener('resize', fitTerminal);
    try {
        const shouldBeOpen = localStorage.getItem('terminal-open') === 'true';
        const terminal = document.getElementById('terminal-container');
        if (shouldBeOpen && terminal) {
            openTerminal(terminal);
            term.focus();
        }
    } catch (e) {
    }
});
