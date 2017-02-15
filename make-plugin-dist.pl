use Modern::Perl;
use File::Copy;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

my $fh;
my %data;

open($fh, "<", "plugin/metadata.txt")
    or die "Can't open < plugin/metadata.txt: $!";
while (<$fh>) {
    if (/(\w+)=(.*)/) {
        $data{$1} = $2;
    }
}
close $fh;

my $zip_dir = lc($data{name});
my $zip_file = lc($data{name}).'.'.$data{version}.'.zip';

unlink $zip_file;

my $download_url = 'http://msp.smartsea.fmi.fi/plugin';
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
    localtime();
$mon++;
for ($sec,$min,$hour) {
    $_ = '0'.$_ if $_ < 10;
}
my $date = $year.'-'.$mon.'-'.$mday.'T'.$hour.':'.$min.':'.$sec;
$data{experimental} = 'True';

my $xml = << "END_XML";
<?xml version = '1.0' encoding = 'UTF-8'?>
<?xml-stylesheet type="text/xsl" href="plugins.xsl" ?>
<plugins>
    <pyqgis_plugin name="$data{name}" version="$data{version}" plugin_id="1">
        <description><![CDATA[$data{description}]]></description>
        <about><![CDATA[]]></about>
        <version>$data{version}</version>
        <trusted>True</trusted>
        <qgis_minimum_version>$data{qgisMinimumVersion}</qgis_minimum_version>
        <qgis_maximum_version>2.99</qgis_maximum_version>
        <homepage><![CDATA[$data{homepage}]]></homepage>
        <file_name>$zip_file</file_name>
        <icon>icon.png</icon>
        <author_name><![CDATA[$data{author}]]></author_name>
        <download_url>$download_url/$zip_file</download_url>
        <uploaded_by><![CDATA[]]></uploaded_by>
        <create_date>$date</create_date>
        <update_date></update_date>
        <experimental>$data{experimental}</experimental>
        <deprecated>False</deprecated>
        <tracker><![CDATA[$data{tracker}]]></tracker>
        <repository><![CDATA[$data{repository}]]></repository>
        <tags><![CDATA[$data{tags}]]></tags>
        <downloads></downloads>
        <average_vote></average_vote>
        <rating_votes></rating_votes>
        <external_dependencies></external_dependencies>
        <server>False</server>
    </pyqgis_plugin>
</plugins>
END_XML

open($fh, ">", "plugin.xml")
    or die "Can't open > plugin.xml: $!";
print $fh $xml;
close $fh;

mkdir $zip_dir;

my @plugin_files = qw/icon.png __init__.py mainPlugin.py metadata.txt dialog.ui configure.ui/;

for my $f (@plugin_files) {
    copy("plugin/$f", "$zip_dir/$f");
}

my $zip = Archive::Zip->new();

# Add a directory
$zip->addDirectory($zip_dir);
for my $f (@plugin_files) {
    $zip->addFile("$zip_dir/$f");
}

# Save the Zip file
unless ( $zip->writeToFileNamed($zip_file) == AZ_OK ) {
    die 'write error';
}

for my $f (@plugin_files) {
    unlink("$zip_dir/$f");
}

rmdir $zip_dir;
