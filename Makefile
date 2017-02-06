schema:
	pg_dump -n tool -n data -s SmartSea >schema.sql

plugin-dist:
	perl make-plugin-dist.pl
