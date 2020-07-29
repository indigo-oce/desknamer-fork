.PHONY: install
install: desknamer.sh desknamer.json
	chmod +x desknamer.sh
	cp desknamer.sh ~/.local/bin/desknamer
	mkdir -p ~/.config/desknamer
	cp desknamer.json ~/.config/desknamer/

.PHONY: uninstall
uninstall:
	rm -f ~/.local/bin/desknamer
