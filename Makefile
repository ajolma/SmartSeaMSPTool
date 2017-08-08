schema:
	pg_dump -n tool -n data -s SmartSea >schema.sql

data:
	pg_dump -a -n tool -n data SmartSea >data-only.sql

tool-schema:
	pg_dump -n tool -s SmartSea >tool-schema.sql

plugin-dist:
	perl make-plugin-dist.pl

plugin-install: plugin/icon.png plugin.xml smartsea.0.0.1.zip
	cp plugin/icon.png /var/www/sites/default
	cp plugin.xml /var/www/sites/default
	cp smartsea.0.0.1.zip /var/www/sites/default

smartsea.0.0.1.zip:
	perl make-plugin-dist.pl

plugin.xml:
	perl make-plugin-dist.pl

test:
	prove -I.

test-js:
	node node_modules/jslint/bin/jslint.js website/js/*.js 

#plugin-test:
#	rm -rf $HOME/.qgis2/python/plugins/smartsea/
#	pwd = `pwd`
#	ln -s $pwd/plugin/ $HOME/.qgis2/python/plugins/smartsea
