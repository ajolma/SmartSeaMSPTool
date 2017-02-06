schema:
	pg_dump -n tool -n data -s SmartSea >schema.sql

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
