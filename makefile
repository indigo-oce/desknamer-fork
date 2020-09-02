.PHONY: install
install: desknamer.sh desknamer.json
	chmod +x desknamer.sh
	cp desknamer.sh ~/.local/bin/desknamer
	mkdir -p ~/.config/desknamer
	cp -n desknamer.json ~/.config/desknamer/
	touch ~/.config/desknamer/monitor.blacklist ~/.config/desknamer/desktop.blacklist

.PHONY: uninstall
uninstall:
	rm -f ~/.local/bin/desknamer
