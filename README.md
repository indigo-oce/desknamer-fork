## desknamer.sh

`desknamer.sh` is a daemon that intelligently renames open `bspwm` desktops according to the applications open inside.

## Installation

To clone to `~/bin/desknamer`, make executable, and add to available commands:

```bash
git clone https://gitlab.com/jallbrit/desknamer ~/bin/desknamer
chmod +x ~/bin/desknamer/desknamer.sh
ln -s ~/bin/desknamer/desknamer.sh ~/.local/bin/desknamer
```

## Usage

```
Usage: desknamer [OPTIONS]

desknamer.sh monitors your open desktops and renames them according to what's inside.

optional args:
  -c, --config FILE     path to alternate configuration file
  -n, --norecursive     don't inspect windows recursively
  -M "MONITOR [MONITOR2]..."
                        specify monitor names or IDs to ignore
  -D "DESKTOP [DESKTOP2]..."
                        specify desktop names or IDs to ignore
  -a, --all             print all applications found on your machine
      --categories      print all categories found on your machine
  -s, --search PROGRAM  find .desktop files matching *program*.desktop
  -g, --get PROGRAM     get categories for given program
  -v, --verbose         make output more verbose
  -h, --help            show help
```

Since `desknamer` is designed to be ran as a daemon, you'll want to run it in the background like so:

```bash
desknamer &
```

## Configuration File

`desknamer` looks for a config file at `~/config/desknamer/desknamer.json` by default, but this can be specified with -c. The configuration file is a JSON file with two keys, `applications` and `categories`, that follow a particular format:

```
{
	"applications": {
		"APPLICATION": "CATEGORY",
		"APPLICATION": "CATEGORY",
		...
	},
	"categories": {
		"CATEGORY": ["NAME", "PRIORITY"],
		"CATEGORY": ["NAME", "PRIORITY"],
		...
	}
}
```

The `applications` key holds categories you wish to add to programs. This key is useful when a given program doesn't have categories at all, or is missing a category you think it should have. At this time, only 1 category can be added to any particular application. E.g:

```
    "urxvt": "TerminalEmulator"
```

The `categories` key holds arrays of length `2`. The name of each array is the name of a category. The array contains:

* 1. A string containing the name to assign to the category
* 2. An integer known as the priority. When multiple categories are found for a single desktop, the category with the lowest priority will take precedence.

The default `desknamer.json` sets the name of common categories to icons from the [Nerd Fonts](https://nerdfonts.com), as well as sets some sane default priorities.

## How Categories are Found

Fortunately for us, most applications installed on your system have a `.desktop` file (likely located in `/usr/share/applications/`) that contains things like:

* Name of the application
* How to execute it
* Categories

These categories allow `desknamer` to know what type of application it's looking at. However, not all programs have corresponding `.desktop` files or a `Categories` entry.


### Priorities and Naming Schemes

`desknamer` names each desktop based on what information it is able to find about nodes (windows) inside:

* **No nodes present**: name is desktop's index on its monitor (e.g. 4)
* **Node(s) present, no categories found**: name is a generic name that represents the presence of unknown applications
* **1 category found**: named that category's name (specified in the configuration file)
* **>1 category found**: `desknamer` checks the priority of each competing category in the configuration file, and the category with the lowest priority is determined to take precedence for the whole desktop. The desktop is named the preceding category's name (specified in the configuration file).

## Why?

`bspwm` only allows for the **static naming** of desktops; some people prefer to leave their desktops named `1, 2, 3, 4` and so forth.

Others prefer to dedicate desktops to certain purposes; e.g., if you want chat applications in desktop `1`, terminals in desktop `2`, a web browser in desktop `3`, and leave desktop `4` open for anything, you may name your desktops `chat term brws 4`.

This static naming can cause confusing and inefficiency, because the name *you* gave the desktop might not be what it ends up being used for. When you start placing terminals in `chat`, and browsers in `term`, you can end up wasting a lot of time looking for your programs. It is possible to rename desktops, but this can be a tedious process.

`desknamer` solves this problem by **dynamically** naming your desktops according to what's inside, thus increasing efficiency for some users.
