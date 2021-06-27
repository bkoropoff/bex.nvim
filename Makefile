doc:
	rm -rf doc/html
	ldoc -c doc/config.ld -d doc/html lua

update-doc: doc
	sh doc/update.sh

.PHONY: doc
