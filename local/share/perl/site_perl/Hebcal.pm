########################################################################
# Hebcal Interactive Jewish Calendar is a web site that lets you
# generate a list of Jewish holidays for any year. Candle lighting
# times are calculated from your latitude and longitude (which can
# be determined by your zip code or closest city).
#
# Copyright (c) 2004  Michael J. Radwin.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or
# without modification, are permitted provided that the following
# conditions are met:
#
#  * Redistributions of source code must retain the above
#    copyright notice, this list of conditions and the following
#    disclaimer.
#
#  * Redistributions in binary form must reproduce the above
#    copyright notice, this list of conditions and the following
#    disclaimer in the documentation and/or other materials
#    provided with the distribution.
#
#  * Neither the name of Hebcal.com nor the names of its
#    contributors may be used to endorse or promote products
#    derived from this software without specific prior written
#    permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
# CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
########################################################################

package Hebcal;
require 5.000;
use strict;
use CGI qw(-no_xhtml);
use POSIX qw(strftime);
use lib "/home/mradwin/local/share/perl";
use lib "/home/mradwin/local/share/perl/site_perl";
use Date::Calc ();
use DB_File;

########################################################################
# constants
########################################################################

my $sedrotfn = '/home/mradwin/web/hebcal.com/hebcal/sedrot.db';
my(%SEDROT);

my $holidaysfn = '/home/mradwin/web/hebcal.com/hebcal/holidays.db';
my(%HOLIDAYS);

my($this_year) = (localtime)[5];
$this_year += 1900;

my($VERSION) = '$Revision$$';
if ($VERSION =~ /(\d+)\.(\d+)/) {
    $VERSION = "$1.$2";
}

$Hebcal::gregorian_warning = "<p><span style=\"color: red\">WARNING:
Results for year 1752 C.E. and before may not be accurate.</span>
Hebcal does not take into account a correction of ten days that
was introduced by Pope Gregory XIII known as the Gregorian
Reformation. For more information, see <a
href=\"http://www.xoc.net/maya/help/gregorian.asp\">Gregorian and
Julian Calendars</a>.</p>";

$Hebcal::indiana_warning = "<p><span style=\"color: red\">WARNING:
Indiana has confusing time zone &amp; Daylight Saving Time
rules.</span><br>Please check <a
href=\"http://www.mccsc.edu/time.html#WHAT\">What time is it in
Indiana?</a> to make sure the above settings are correct.</p>";


# boolean options
@Hebcal::opts = ('c','o','s','i','a','d','D');

$Hebcal::havdalah_min = 72;
@Hebcal::DoW = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
@Hebcal::MoY_short =
    ('Jan','Feb','Mar','Apr','May','Jun',
     'Jul','Aug','Sep','Oct','Nov','Dec');
%Hebcal::MoY_long = (
	     'x' => '- Entire year -',
	     1   => 'January',
	     2   => 'February',
	     3   => 'March',
	     4   => 'April',
	     5   => 'May',
	     6   => 'June',
	     7   => 'July',
	     8   => 'August',
	     9   => 'September',
	     10  => 'October',
	     11  => 'November',
	     12  => 'December',
	     );

%Hebcal::dst_names =
    (
     'none'    => 'none',
     'usa'     => 'USA, Mexico, Canada',
     'israel'  => 'Israel',
     'eu'      => 'European Union',
     'aunz'    => 'Australia and NZ',
     );

%Hebcal::cities =
    (
     'Ashdod'		=>	[2,'israel'],
     'Atlanta'		=>	[-5,'usa'],
     'Austin'		=>	[-6,'usa'],
     'Baghdad'		=>	[3,'eu'],
     'Berlin'		=>	[1,'eu'],
     'Beer Sheva'	=>	[2,'israel'],
     'Baltimore'	=>	[-5,'usa'],
     'Bogota'		=>	[-5,'none'],
     'Boston'		=>	[-5,'usa'],
     'Buenos Aires'	=>	[-3,'none'],
     'Buffalo'		=>	[-5,'usa'],
     'Chicago'		=>	[-6,'usa'],
     'Cincinnati'	=>	[-5,'usa'],
     'Cleveland'	=>	[-5,'usa'],
     'Dallas'		=>	[-6,'usa'],
     'Denver'		=>	[-7,'usa'],
     'Detroit'		=>	[-5,'usa'],
     'Eilat'		=>	[2,'israel'],
     'Gibraltar'	=>	[-10,'usa'],
     'Haifa'		=>	[2,'israel'],
     'Hawaii'		=>	[-10,'none'],
     'Houston'		=>	[-6,'usa'],
     'Jerusalem'	=>	[2,'israel'],
     'Johannesburg'	=>	[2,'none'],
     'Kiev'		=>	[2,'eu'],
     'La Paz'		=>	[-4,'none'],
     'London'		=>	[0,'eu'],
     'Los Angeles'	=>	[-8,'usa'],
     'Miami'		=>	[-5,'usa'],
     'Melbourne'	=>	[10,'aunz'],
     'Mexico City'	=>	[-6,'usa'],
     'Montreal'		=>	[-5,'usa'],
     'Moscow'		=>	[3,'eu'],
     'New York'		=>	[-5,'usa'],
     'Omaha'		=>	[-7,'usa'],
     'Ottawa'		=>	[-5,'usa'],
     'Paris'		=>	[1,'eu'],
     'Petach Tikvah'	=>	[2,'israel'],
     'Philadelphia'	=>	[-5,'usa'],
     'Phoenix'		=>	[-7,'none'],
     'Pittsburgh'	=>	[-5,'usa'],
     'Saint Louis'	=>	[-6,'usa'],
     'Saint Petersburg'	=>	[3,'eu'],
     'San Francisco'	=>	[-8,'usa'],
     'Seattle'		=>	[-8,'usa'],
     'Sydney'		=>	[10,'aunz'],
     'Tel Aviv'		=>	[2,'israel'],
     'Tiberias'		=>	[2,'israel'],
     'Toronto'		=>	[-5,'usa'],
     'Vancouver'	=>	[-8,'usa'],
     'Washington DC'	=>	[-5,'usa'],
     );

%Hebcal::city_tz =
    (
     );

%Hebcal::city_dst =
    (
     );

while (my($key,$val) = each %Hebcal::cities)
{
    $Hebcal::city_tz{$key} = $val->[0];
    $Hebcal::city_dst{$key} = $val->[1];
}


# translate from Askenazic transiliterations to Separdic
%Hebcal::ashk2seph =
 (
  # parshiot translations
  "Bereshis"			=>	"Bereshit",
  "Toldos"			=>	"Toldot",
  "Shemos"			=>	"Shemot",
  "Yisro"			=>	"Yitro",
  "Ki Sisa"			=>	"Ki Tisa",
  "Sazria"			=>	"Tazria",
  "Achrei Mos"			=>	"Achrei Mot",
  "Bechukosai"			=>	"Bechukotai",
  "Beha'aloscha"		=>	"Beha'alotcha",
  "Chukas"			=>	"Chukat",
  "Matos"			=>	"Matot",
  "Vaeschanan"			=>	"Vaetchanan",
  "Ki Seitzei"			=>	"Ki Teitzei",
  "Ki Savo"			=>	"Ki Tavo",

  # fixed holiday translations
  "Erev Sukkos"			=>	"Erev Sukkot",
  "Sukkos I"			=>	"Sukkot I",
  "Sukkos II"			=>	"Sukkot II",
  "Sukkos III (CH''M)"		=>	"Sukkot III (CH''M)",
  "Sukkos IV (CH''M)"		=>	"Sukkot IV (CH''M)",
  "Sukkos V (CH''M)"		=>	"Sukkot V (CH''M)",
  "Sukkos VI (CH''M)"		=>	"Sukkot VI (CH''M)",
  "Sukkos VII (Hoshana Raba)"	=>	"Sukkot VII (Hoshana Raba)",
  "Shmini Atzeres"		=>	"Shmini Atzeret",
  "Simchas Torah"		=>	"Simchat Torah",
  "Erev Shavuos"		=>	"Erev Shavuot",
  "Shavuos I"			=>	"Shavuot I",
  "Shavuos II"			=>	"Shavuot II",

  # variable holidays
  "Ta'anis Esther"		=>	"Ta'anit Esther",
  "Purim Koson"			=>	"Purim Katan",
  "Ta'anis Bechoros"		=>	"Ta'anit Bechorot",

  # special shabbatot
  "Shabbas Shuvah"		=>	"Shabbat Shuva",
  "Shabbas Shekalim"		=>	"Shabbat Shekalim",
  "Shabbas Zachor"		=>	"Shabbat Zachor",
  "Shabbas Parah"		=>	"Shabbat Parah",
  "Shabbas HaChodesh"		=>	"Shabbat HaChodesh",
  "Shabbas HaGadol"		=>	"Shabbat HaGadol",
  "Shabbas Hazon"		=>	"Shabbat Hazon",
  "Shabbas Nachamu"		=>	"Shabbat Nachamu",
  );

%Hebcal::tz_names = (
     'auto' => '- Attempt to auto-detect -',
     '-5'   => 'GMT -05:00 (U.S. Eastern)',
     '-6'   => 'GMT -06:00 (U.S. Central)',
     '-7'   => 'GMT -07:00 (U.S. Mountain)',
     '-8'   => 'GMT -08:00 (U.S. Pacific)',
     '-9'   => 'GMT -09:00 (U.S. Alaskan)',
     '-10'  => 'GMT -10:00 (U.S. Hawaii)',
     '-11'  => 'GMT -11:00',
     '-12'  => 'GMT -12:00',
     '12'   => 'GMT +12:00',
     '11'   => 'GMT +11:00',
     '10'   => 'GMT +10:00',
     '9'    => 'GMT +09:00',
     '8'    => 'GMT +08:00',
     '7'    => 'GMT +07:00',
     '6'    => 'GMT +06:00',
     '5'    => 'GMT +05:00',
     '4'    => 'GMT +04:00',
     '3'    => 'GMT +03:00',
     '2'    => 'GMT +02:00',
     '1'    => 'GMT +01:00',
     '0'    => 'Greenwich Mean Time',
     '-1'   => 'GMT -01:00',
     '-2'   => 'GMT -02:00',
     '-3'   => 'GMT -03:00',
     '-4'   => 'GMT -04:00',
     );

# @events is an array of arrays.  these are the indices into each
# event structure:

$Hebcal::EVT_IDX_SUBJ = 0;		# title of event
$Hebcal::EVT_IDX_UNTIMED = 1;		# 0 if all-day, non-zero if timed
$Hebcal::EVT_IDX_MIN = 2;		# minutes, [0 .. 59]
$Hebcal::EVT_IDX_HOUR = 3;		# hour of day, [0 .. 23]
$Hebcal::EVT_IDX_MDAY = 4;		# day of month, [1 .. 31]
$Hebcal::EVT_IDX_MON = 5;		# month of year, [0 .. 11]
$Hebcal::EVT_IDX_YEAR = 6;		# year [1 .. 9999]
$Hebcal::EVT_IDX_DUR = 7;		# duration in minutes
$Hebcal::EVT_IDX_MEMO = 8;		# memo text
$Hebcal::EVT_IDX_YOMTOV = 9;		# is the holiday Yom Tov?

my(%num2heb) =
(
1 => 'א',
2 => 'ב',
3 => 'ג',
4 => 'ד',
5 => 'ה',
6 => 'ו',
7 => 'ז',
8 => 'ח',
9 => 'ט',
10 => 'י',
20 => 'כ',
30 => 'ל',
40 => 'מ',
50 => 'נ',
60 => 'ס',
70 => 'ע',
80 => 'פ',
90 => 'צ',
100 => 'ק',
200 => 'ר',
300 => 'ש',
400 => 'ת',
);

my(%monthnames) =
(
'Nisan'		=> 'נִיסָן',
'Iyyar'		=> 'אִיָיר',
'Sivan'		=> 'סִיוָן',
'Tamuz'		=> 'תָּמוּז',
'Av'		=> 'אָב',
'Elul'		=> 'אֱלוּל',
'Tishrei'	=> 'תִּשְׁרֵי',
'Cheshvan'	=> 'חֶשְׁוָן',
'Kislev'	=> 'כִּסְלֵו',
'Tevet'		=> 'טֵבֵת',
"Sh'vat"	=> 'שְׁבָט',
'Adar'		=> 'אַדָר',
'Adar I'	=> 'אַדָר א׳',
'Adar II'	=> 'אַדָר ב׳',
);

########################################################################
# invoke hebcal unix app and create perl array of output
########################################################################

sub parse_date_descr($$)
{
    my($date,$descr) = @_;
    my($dur,$untimed);
    my($subj,$hour,$min);

    if ($descr =~ /^(.+)\s*:\s*(\d+):(\d+)\s*$/)
    {
	($subj,$hour,$min) = ($1,$2,$3);
	$hour += 12;		# timed events are always evening

	if ($subj eq 'Candle lighting')
	{
	    $dur = 18;
	}
	else
	{
	    $dur = 1;
	}

	$untimed = 0;
    }
    else
    {
	$hour = $min = -1;
	$dur = 0;
	$untimed = 1;
	$subj = $descr;
	$subj =~ s/Channukah/Chanukah/; # make spelling consistent
    }

    my($yomtov) = 0;
    my($subj_copy) = $subj;

    $subj_copy = $Hebcal::ashk2seph{$subj_copy}
	if defined $Hebcal::ashk2seph{$subj_copy};
    $subj_copy =~ s/ \d{4}$//; # fix Rosh Hashana

    unless(tied(%HOLIDAYS)) {
	tie(%HOLIDAYS, 'DB_File', $holidaysfn, O_RDONLY, 0444, $DB_File::DB_HASH)
	    || warn "Can't tie $holidaysfn";
    }

    $yomtov = 1  if $HOLIDAYS{"$subj_copy:yomtov"};

    $subj =~ s/\"/''/g;
    $subj =~ s/\s*:\s*$//g;

    my($mon,$mday,$year) = split(/\//, $date);

    if (($subj eq 'Yom HaZikaron' || $subj eq "Yom HaAtzma'ut") &&
	($year == 2004)) {
	$mday++;
    }

    ($subj,$untimed,$min,$hour,$mday,$mon - 1,$year,$dur,$yomtov);
}

sub invoke_hebcal($$$)
{
    my($cmd,$memo,$want_sephardic) = @_;
    my(@events,$prev);
    local($_);
    local(*HEBCAL);

    @events = ();
    open(HEBCAL,"$cmd |") || die "Can't exec '$cmd': $!\n";

    $prev = '';
    while (<HEBCAL>)
    {
	next if $_ eq $prev;
	$prev = $_;
	chop;

	my($date,$descr) = split(/ /, $_, 2);
	my($subj,$untimed,$min,$hour,$mday,$mon,$year,$dur,$yomtov) =
	    parse_date_descr($date,$descr);

	# if Candle lighting and Havdalah are on the same day it is
	# a bug in hebcal for unix involving shabbos and chag overlap.
	# suppress inconsistent times until we can get hebcal fixed.
	if ($subj =~ /^Havdalah/ && $#events >= 0 &&
	    $events[$#events]->[$Hebcal::EVT_IDX_MDAY] == $mday &&
	    $events[$#events]->[$Hebcal::EVT_IDX_SUBJ] =~ /^Candle lighting/)
	{
	    pop(@events);
	    next;
	}

	next if $subj eq 'Havdalah (0 min)';

	my($memo2) = (Hebcal::get_holiday_anchor($subj,$want_sephardic,undef))[2];

	push(@events,
	     [$subj,$untimed,$min,$hour,$mday,$mon,$year,$dur,
	      ($untimed ? $memo2 : $memo),$yomtov]);
    }
    close(HEBCAL);

    @events;
}

sub get_dow($$$)
{
    my($year,$mon,$mday) = @_;

    my($dow) = &Date::Calc::Day_of_Week($year,$mon,$mday);
    $dow == 7 ? 0 : $dow;
}
sub hebnum_to_array {
    my($num) = @_;
    my(@result) = ();

    $num = $num % 1000;

    while ($num > 0)
    {
	my($incr) = 100;

	if ($num == 15 || $num == 16)
	{
	    push(@result, 9, $num - 9);
	    last;
	}

	my($i);
	for ($i = 400; $i > $num; $i -= $incr)
	{
	    if ($i == $incr)
	    {
		$incr = int($incr / 10);
	    }
	}

	push(@result, $i);

	$num -= $i;
    }

    @result;
}

sub hebnum_to_string {
    my($num) = @_;

    my(@array) = hebnum_to_array($num);
    my $digits = scalar(@array);
    my($result);

    if ($digits == 1)
    {
	$result = $num2heb{$array[0]} . '׳'; # geresh
    }
    else
    {
	$result = '';
	for (my $i = 0; $i < $digits; $i++)
	{
	    $result .= '״' if (($i + 1) == $digits); # gershayim
	    $result .= $num2heb{$array[$i]};
	}
    }

    $result;
}

sub build_hebrew_date($$$)
{
    my($hm,$hd,$hy) = @_;

    hebnum_to_string($hd) . " \327\221\326\274\326\260" .
	$monthnames{$hm} . " " . hebnum_to_string($hy);
}

sub make_anchor($)
{
    my($f) = @_;

    my($anchor) = lc($f);
    $anchor =~ s/\'//g;
    $anchor =~ s/[^\w]/-/g;
    $anchor =~ s/-+/-/g;
    $anchor =~ s/^-//g;
    $anchor =~ s/-$//g;

    "$anchor.html";
}

sub get_holiday_anchor($$$)
{
    my($subj,$want_sephardic,$q) = @_;
    my($href) = '';
    my($hebrew) = '';
    my($memo) = '';

    unless(tied(%SEDROT)) {
	tie(%SEDROT, 'DB_File', $sedrotfn, O_RDONLY, 0444, $DB_File::DB_HASH)
	    || die "Can't tie $sedrotfn";
    }

    unless(tied(%HOLIDAYS)) {
	tie(%HOLIDAYS, 'DB_File', $holidaysfn, O_RDONLY, 0444, $DB_File::DB_HASH)
	    || die "Can't tie $holidaysfn";
    }

    if ($subj =~ /^(Parshas\s+|Parashat\s+)(.+)$/)
    {
	my($parashat) = $1;
	my($sedra) = $2;

	# 'פרשת ' == UTF-8 for "parashat "
	$hebrew = "\xD7\xA4\xD7\xA8\xD7\xA9\xD7\xAA ";
	$sedra = $Hebcal::ashk2seph{$sedra} if (defined $Hebcal::ashk2seph{$sedra});

	if (defined $SEDROT{$sedra})
	{
	    my($anchor) = $sedra;
	    $anchor = lc($anchor);
	    $anchor =~ s/[^\w]//g;

	    $href = 'http://' . $q->virtual_host()
		if ($q);
	    $href .= "/sedrot/$anchor.html";

	    $hebrew .= $SEDROT{"$sedra:hebrew"};
	}
	elsif (($sedra =~ /^([^-]+)-(.+)$/) &&
	       (defined $SEDROT{$1} || defined $SEDROT{$Hebcal::ashk2seph{$1}}))
	{
	    my($p1,$p2) = ($1,$2);

	    $p1 = $Hebcal::ashk2seph{$p1} if (defined $Hebcal::ashk2seph{$p1});
	    $p2 = $Hebcal::ashk2seph{$p2} if (defined $Hebcal::ashk2seph{$p2});

	    die "sedrot.db missing $p2!" unless defined $SEDROT{$p2};

	    my($anchor) = "$p1-$p2";
	    $anchor = lc($anchor);
	    $anchor =~ s/[^\w]//g;

	    $href = 'http://' . $q->virtual_host()
		if ($q);
	    $href .= "/sedrot/$anchor.html";

	    $hebrew .= $SEDROT{"$p1:hebrew"};

	    # hypenate hebrew reading
	    # '־' == UTF-8 for HEBREW PUNCTUATION MAQAF (U+05BE)
	    $hebrew .= "\xD6\xBE" . $SEDROT{"$p2:hebrew"};
	}
    }
    elsif ($subj =~ /^(\d+)\w+ day of the Omer$/)
    {
	$hebrew = hebnum_to_string($1) .
	" בְּעוֹמֶר";
    }
    elsif ($subj =~ /^(\d+)\w+ of ([^,]+), (\d+)$/)
    {
	my($hm,$hd,$hy) = ($2,$1,$3);

	$hebrew = build_hebrew_date($hm,$hd,$hy);
    }
    else
    {
	my($subj_copy) = $subj;

	$subj_copy = $Hebcal::ashk2seph{$subj_copy}
	    if defined $Hebcal::ashk2seph{$subj_copy};

	$subj_copy =~ s/ \d{4}$//; # fix Rosh Hashana

	if (defined $HOLIDAYS{$subj_copy} && defined $HOLIDAYS{"$subj_copy:hebrew"})
	{
	    $hebrew = $HOLIDAYS{"$subj_copy:hebrew"};
	}

	if ($subj ne 'Candle lighting' && $subj !~ /^Havdalah/ &&
	    $subj ne 'No sunset today.')
	{
	    $subj_copy =~ s/ \(CH\'\'M\)$//;
	    $subj_copy =~ s/ \(Hoshana Raba\)$//;
	    $subj_copy =~ s/ [IV]+$//;
	    $subj_copy =~ s/: \d Candles?$//;
	    $subj_copy =~ s/: 8th Day$//;
	    $subj_copy =~ s/^Erev //;

	    $href = 'http://' . $q->virtual_host()
		if ($q);
	    $href .= "/holidays/" . make_anchor($subj_copy);
	}
    }

    return (wantarray()) ?
	($href,$hebrew,$memo)
	: $href;
}
    


########################################################################
# web page utils
########################################################################

sub out_html
{
    my($cfg,@args) = @_;

    if (defined $cfg && $cfg eq 'j')
    {
	print STDOUT "document.write(\"";
	foreach (@args)
	{
	    s/\"/\\\"/g;
	    s/\n/\\n/g;
	    print STDOUT;
	}
	print STDOUT "\");\n";
    }
    else
    {
	foreach (@args)
	{
	    print STDOUT;
	}
    }

    1;
}

sub zipcode_open_db
{
    use DB_File;

    my($dbmfile) = $_[0] ? $_[0] : 'zips99.db';
    my(%DB);
    tie(%DB, 'DB_File', $dbmfile, O_RDONLY, 0444, $DB_File::DB_HASH)
	|| die "Can't tie $dbmfile: $!\n";

    \%DB;
}

sub zipcode_close_db($)
{
    use DB_File;

    my($DB) = @_;
    untie(%{$DB});
}

sub zipcode_fields($)
{
    my($value) = @_;

    my($latitude,$longitude,$tz,$dst,$city,$state) = split(/,/, $value);

    if (! defined $state)
    {
	warn "zips99: bad data for $value";
	return undef;
    }

    # remove any prefixed + signs from the strings
    $latitude =~ s/^\+//;
    $longitude =~ s/^\+//;

    # in hebcal, negative longitudes are EAST (this is backwards)
    $longitude *= -1.0;

    my($long_deg,$long_min) = split(/\./, $longitude, 2);
    my($lat_deg,$lat_min) = split(/\./, $latitude, 2);

    if (defined $long_min && $long_min ne '')
    {
	$long_min = '.' . $long_min;
    }
    else
    {
	$long_min = 0;
    }

    if (defined $lat_min && $lat_min ne '')
    {
	$lat_min = '.' . $lat_min;
    }
    else
    {
	$lat_min = 0;
    }

    $long_min = $long_min * 60;
#    $long_min *= -1 if $long_deg < 0;
    $long_min = sprintf("%.0f", $long_min);

    $lat_min = $lat_min * 60;
    $lat_min *= -1 if $lat_deg < 0;
    $lat_min = sprintf("%.0f", $lat_min);

    my(@city) = split(/([- ])/, $city);
    $city = '';
    foreach (@city)
    {
	$_ = lc($_);
	$_ = "\u$_";		# inital cap
	$city .= $_;
    }

    if (($state eq 'HI' || $state eq 'AZ') && $dst == 1)
    {
	warn "[$city, $state] had DST=1 but should be 0";
	$dst = 0;
    }

    ($long_deg,$long_min,$lat_deg,$lat_min,$tz,$dst,$city,$state);
}

sub html_copyright2($$$)
{
    my($prefix,$break,$target) = @_;

    my($br) = $break ? '<br>' : '';
    my($tgt) = $target ? $target : '_top';

    return qq{<a name="copyright"></a>Copyright &copy; $this_year
Michael J. Radwin. All rights reserved.$br
<a target="$tgt" href="$prefix/privacy/">Privacy Policy</a> -
<a target="$tgt" href="$prefix/help/">Help</a> -
<a target="$tgt" href="$prefix/contact/">Contact</a> -
<a target="$tgt" href="$prefix/news/">News</a> -
<a target="$tgt" href="$prefix/donations/">Donate</a>};
}

sub html_copyright($$$)
{
    my($q,$break,$tgt) = @_;

    my($server_name) = $q->virtual_host();
    return html_copyright2("http://$server_name", $break, $tgt);
}

sub html_footer($$)
{
    my($q,$rcsrev) = @_;

    my($mtime) = (defined $ENV{'SCRIPT_FILENAME'}) ?
	(stat($ENV{'SCRIPT_FILENAME'}))[9] : time;

    $rcsrev =~ s/\s*\$//g;

    my($server_name) = $q->virtual_host();
    $server_name =~ s/^www\.//;

    my($hhmts) = "Software last updated:\n" . localtime($mtime);

    return qq{
<hr noshade size="1"><span class="tiny">
}, html_copyright($q, 0, undef), qq{
<br>This website uses <a href="http://sourceforge.net/projects/hebcal/">hebcal
3.3 for UNIX</a>, Copyright &copy; 2002 Danny Sadinoff. All rights reserved.
<br>$hhmts ($rcsrev)
</span></body></html>
};
}

sub navbar2($$$$$)
{
    my($q,$title,$help,$parent_title,$parent_href) = @_;

    my($server_name) = $q->virtual_host();
    $server_name =~ s/^www\.//;

    my($help_html) = ($help) ? "href=\"/help/\">Help</a> -\n<a\n" : '';

    my($parent_html) = ($parent_title && $parent_href) ? 
	qq{<tt>-&gt;</tt>\n<a\nhref="$parent_href">$parent_title</a>\n} :
	'';

    return "\n<!--htdig_noindex-->\n" .
	"<table width=\"100%\"\nclass=\"navbar\">" .
	"<tr><td><small>" .
	"<strong><a\nhref=\"/\">" . $server_name . "</a></strong>\n" .
	$parent_html .
	"<tt>-&gt;</tt>\n" .
	$title . "</small></td>" .
	"<td align=\"right\"><small><a\n" .
	$help_html .
	"href=\"/search/\">Search</a></small>\n" .
	"</td></tr></table>\n" .
	"<!--/htdig_noindex-->\n";
}

sub start_html($$$$$)
{
    my($q,$title,$head,$meta,$target) = @_;

    $q->default_dtd("-//W3C//DTD HTML 4.01 Transitional//EN\"\n" .
		    "\t\"http://www.w3.org/TR/html4/loose.dtd");

    $meta = {} unless defined $meta;
    $head = [] unless defined $head;

    my $base;

    if ($ENV{'QUERY_STRING'})
    {
	my($script_name) = $q->script_name();
	$script_name =~ s,/index.cgi$,/,;

	my $qs = $ENV{'QUERY_STRING'};
	$qs =~ s/&/&amp;/g;

	$base = "http://" . $q->virtual_host() . $script_name . "?" . $qs;
    }

    $target = '_top' unless defined $target;
    return $q->start_html
	(
	 -dir => 'ltr',
	 -lang => 'en',
	 -title => $title,
	 -target => $target,
	 -xbase => $base,
	 -head => [
		   $q->Link({-rel => 'stylesheet',
			     -href => '/style.css',
			     -type => 'text/css'}),
		   @{$head},
		   ],
	 -meta => $meta,
	 );
}

sub html_entify($)
{
    local($_) = @_;

    s/&/&amp;/g;
    s/</&lt;/g;
    s/>/&gt;/g;
    s/"/&quot;/g; #"#
    s/\s+/ /g;

    $_;
}

sub url_escape($)
{
    local($_) = @_;
    my($res) = '';

    foreach (split(//))
    {
	if (/ /)
	{
	    $res .= '+';
	}
	elsif (/[^a-zA-Z0-9_.*-]/)
	{
	    $res .= sprintf("%%%02X", ord($_));
	}
	else
	{
	    $res .= $_;
	}
    }

    $res;
}

sub http_date($)
{
    my($time) = @_;

    strftime("%a, %d %b %Y %T GMT", gmtime($time));
}

sub gen_cookie($)
{
    my($q) = @_;
    my($retval);

    $retval = 'C=t=' . time;

    if ($q->param('c') && $q->param('c') ne 'off')
    {
	if ($q->param('geo') eq 'zip') {
	    $retval .= '&zip=' . $q->param('zip');
	    $retval .= '&dst=' . $q->param('dst')
	        if defined $q->param('dst') && $q->param('dst') ne '';
	    $retval .= '&tz=' . $q->param('tz')
	        if defined $q->param('tz') && $q->param('tz') ne '';
	} elsif ($q->param('geo') eq 'city') {
	    $retval .= '&city=' . &url_escape($q->param('city'));
	} elsif ($q->param('geo') eq 'pos') {
	    $retval .= '&lodeg=' . $q->param('lodeg');
	    $retval .= '&lomin=' . $q->param('lomin');
	    $retval .= '&lodir=' . $q->param('lodir');
	    $retval .= '&ladeg=' . $q->param('ladeg');
	    $retval .= '&lamin=' . $q->param('lamin');
	    $retval .= '&ladir=' . $q->param('ladir');
	    $retval .= '&dst=' . $q->param('dst')
	        if defined $q->param('dst') && $q->param('dst') ne '';
	    $retval .= '&tz=' . $q->param('tz')
	        if defined $q->param('tz') && $q->param('tz') ne '';
	}
	$retval .= '&m=' . $q->param('m')
	    if defined $q->param('m') && $q->param('m') ne '';
    }

    foreach (@Hebcal::opts)
    {
	next if $_ eq 'c' || $_ eq 'H';
	$retval .= "&$_=" . $q->param($_)
	    if defined $q->param($_) && $q->param($_) ne '';
    }
    $retval .= '&nh=off'
	if !defined $q->param('nh') || $q->param('nh') eq 'off';
    $retval .= '&nx=off'
	if !defined $q->param('nx') || $q->param('nx') eq 'off';

    if (defined $q->param('heb') && $q->param('heb') ne '')
    {
	$retval .= "&heb=" . $q->param('heb');
    }
    else
    {
	$retval .= '&heb=off';
    }

    $retval;
}

sub get_cookies($)
{
    my($q) = @_;

    my($raw) = $q->raw_cookie();
    my(%cookies) = ();
    if ($raw)
    {
	foreach (split(/[;,\s]/, $raw))
	{
	    my($key,$val) = split(/=/, $_, 2);
	    next unless $key;
	    $val = '' unless defined($val);
	    $cookies{$key} = $val;
	}
    }

    \%cookies;
}

sub process_cookie($$)
{
    my($q,$cookieval) = @_;

    $cookieval =~ s/^C=//;

    if ($cookieval eq 'opt_out') {
	return undef;
    }

    my($c) = new CGI($cookieval);

    if ((! defined $q->param('c')) ||
	($q->param('c') eq 'on') ||
	($q->param('c') eq '1')) {
	if (defined $c->param('zip') && $c->param('zip') =~ /^\d{5}$/ &&
	    (! defined $q->param('geo') || $q->param('geo') eq 'zip')) {
	    $q->param('geo','zip');
	    $q->param('c','on');
	    if (! defined $q->param('zip') || $q->param('zip') =~ /^\s*$/)
	    {
		$q->param('zip',$c->param('zip'));
		$q->param('dst',$c->param('dst'))
		    if defined $c->param('dst');
		$q->param('tz',$c->param('tz'))
		    if defined $c->param('tz');
	    }
	} elsif (defined $c->param('city') && $c->param('city') ne '' &&
		 (! defined $q->param('geo') || $q->param('geo') eq 'city')) {
	    $q->param('city',$c->param('city'))
		unless $q->param('city');
	    $q->param('geo','city');
	    $q->param('c','on');
	    $q->delete('tz');
	    $q->delete('dst');
	    if (defined $Hebcal::city_dst{$q->param('city')} &&
		$Hebcal::city_dst{$q->param('city')} eq 'israel')
	    {
		$q->param('i','on');
		$c->param('i','on');
	    }
	} elsif (defined $c->param('lodeg') &&
		 defined $c->param('lomin') &&
		 defined $c->param('lodir') &&
		 defined $c->param('ladeg') &&
		 defined $c->param('lamin') &&
		 defined $c->param('ladir') &&
		 (! defined $q->param('geo') || $q->param('geo') eq 'pos')) {
	    $q->param('lodeg',$c->param('lodeg'))
		unless $q->param('lodeg');
	    $q->param('lomin',$c->param('lomin'))
		unless $q->param('lomin');
	    $q->param('lodir',$c->param('lodir'))
		unless $q->param('lodir');
	    $q->param('ladeg',$c->param('ladeg'))
		unless $q->param('ladeg');
	    $q->param('lamin',$c->param('lamin'))
		unless $q->param('lamin');
	    $q->param('ladir',$c->param('ladir'))
		unless $q->param('ladir');
	    $q->param('geo','pos');
	    $q->param('c','on');
	    $q->param('dst',$c->param('dst'))
		if (defined $c->param('dst') && ! defined $q->param('dst'));
	    $q->param('tz',$c->param('tz'))
		if (defined $c->param('tz') && ! defined $q->param('tz'));
	}
    }

    $q->param('m',$c->param('m'))
	if (defined $c->param('m') && ! defined $q->param('m'));

    foreach (@Hebcal::opts)
    {
	next if $_ eq 'c';
	$q->param($_,$c->param($_))
	    if (! defined $q->param($_) && defined $c->param($_));
    }

#    $q->param('nh','off')
#	if (defined $c->param('h') && $c->param('h') eq 'on');
#    $q->param('nx','off')
#	if (defined $c->param('x') && $c->param('x') eq 'on');

    $q->param('nh',$c->param('nh'))
	if (! defined $q->param('nh') && defined $c->param('nh'));
    $q->param('nx',$c->param('nx'))
	if (! defined $q->param('nx') && defined $c->param('nx'));
    $q->param('heb',$c->param('heb'))
	if (! defined $q->param('heb') && defined $c->param('heb'));

    $c;
}

########################################################################
# EXPORT
########################################################################

sub self_url($$)
{
    my($q,$override) = @_;

    my($script_name) = $q->script_name();
    $script_name =~ s,/index.cgi$,/,;

    my($url) = $script_name;
    my($sep) = '?';

    foreach my $key ($q->param())
    {
	next if $key eq 'tag' && !defined $override->{$key};

	my($val) = defined $override->{$key} ?
	    $override->{$key} : $q->param($key);
	$url .= "$sep$key=" . Hebcal::url_escape($val);
	$sep = ';' if $sep eq '?';
    }

    foreach my $key (keys %{$override})
    {
	unless (defined $q->param($key))
	{
	    $url .= "$sep$key=" . Hebcal::url_escape($override->{$key});
	    $sep = ';' if $sep eq '?';
	}
    }

    $url;
}

sub download_href
{
    my($q,$filename,$ext) = @_;

    my($script_name) = $q->script_name();
    $script_name =~ s,/index.cgi$,/,;

    my($href) = $script_name;
    $href .= "index.cgi" if $q->script_name() =~ m,/index.cgi$,;
    $href .= "/$filename.$ext?dl=1";
    foreach my $key ($q->param())
    {
	my($val) = $q->param($key);
	$href .= ";$key=" . Hebcal::url_escape($val);
    }

    $href;
}

sub download_html
{
    my($q, $filename, $events, $title) = @_;

    my($greg_year1,$greg_year2) = (0,0);
    my($numEntries) = scalar(@{$events});
    if ($numEntries > 0)
    {
	$greg_year1 = $events->[0]->[$Hebcal::EVT_IDX_YEAR];
	$greg_year2 = $events->[$numEntries - 1]->[$Hebcal::EVT_IDX_YEAR];
    }

    $title = '' unless $title;

    my($s) = qq{<div class="goto"><a name="export"></a><hr>\n} .
    qq{<h3>Export $title calendar</h3>\n};

    $s .= qq{<p>By clicking the links below, you can download 
Jewish Calendar events into your desktop software.</p>};

    if ($title && defined $q->param('month') && $q->param('month') ne 'x')
    {
	my $end_day = Date::Calc::Days_in_Month($q->param('year'),
						$q->param('month'));
	my $hebdate = Hebcal::greg2hebrew($q->param('year'),
					  $q->param('month'),
					  $end_day);
	my $heb_year = $hebdate->{'yy'};

	$s .= "<p>Note: you may also download <a\n" .
	    "href=\"" . Hebcal::self_url($q, {'month' => 'x'})
	    . "#export\">all of " . $q->param('year') . "</a> or <a\n" .
	    "href=\"" .
	    Hebcal::self_url($q, {'yt' => 'H', 'month' => 'x', 'year' => $heb_year}) .
	    "#export\">Hebrew Year $heb_year</a> events.</p>\n";
    }

    $s .= "<h4>Microsoft Outlook</h4>\n<ol><li>Export Outlook CSV file.\nSelect one of:\n" .
	"<ul><li>USA date format (month/day/year):\n" .
	"<a href=\"" . download_href($q, "${filename}_usa", 'csv') .
	"\">${filename}_usa.csv</a>\n";

    $s .= "<li>European date format (day/month/year):\n" .
	"<a href=\"" . download_href($q, "${filename}_eur", 'csv') .
	";euro=1\">${filename}_eur.csv</a></ul>\n";

    $s .= qq{<li><a href="/help/import.html#csv">How to import CSV file into Outlook</a></ol>};

    # only offer DBA export when we know timegm() will work
    if ($greg_year1 > 1969 && $greg_year2 < 2038 &&
	(!defined($q->param('dst')) || $q->param('dst') eq 'usa'
	 || $q->param('dst') eq 'none'))
    {
	$s .= "<h4>Palm Desktop for Windows</h4>\n<ol><li>" .
	    "Export Palm Date Book Archive:\n" .
	    "<a href=\"" .
	    download_href($q, $filename, 'dba') .
	    "\">$filename.dba</a>\n";
	$s .= qq{<li><a href="/help/import.html#dba">How to import DBA file into Palm Desktop</a></ol>};
    }

    my $ical_href = download_href($q, $filename, 'ics');

    $s .= "<h4>Apple iCal (and other iCalendar-enabled applications)</h4>\n<ol><li>" .
	"Export iCalendar file:\n" .
	"<a href=\"webcal://" . $q->virtual_host() . $ical_href .
	    "\">subscribe</a> or\n" .
	"<a href=\"" .
	$ical_href .
	    "\">download</a>\n";
    $s .= qq{<li>How to import ICS file into <a href="/help/import.html#ical">Apple iCal</a> or <a href="/help/import.html#lotus-notes">Lotus Notes 6</a></ol>};

    $s .= "<h4>Palm Desktop 2.6.3 for Macintosh</h4>\n<ol><li>" .
	"Export Mac Palm Calendar:\n" .
	"<a href=\"" .
	download_href($q, $filename, 'tsv') .
	    "\">$filename.tsv</a>\n";
    $s .= "<li>(this feature is currently experimental)</ol>\n";

    $s .= "<h4>vCalendar (some older desktop applications)</h4>\n<ol><li>" .
	"Export vCalendar file:\n" .
	"<a href=\"" .
	download_href($q, $filename, 'vcs') .
	    "\">$filename.vcs</a>\n";
    $s .= "<li>(this feature is currently experimental)</ol>\n";

    $s .= "</div>\n";

    $s;
}

sub export_http_header($$)
{
    my($q,$mime) = @_;

    my($time) = defined $ENV{'SCRIPT_FILENAME'} ?
	(stat($ENV{'SCRIPT_FILENAME'}))[9] : time;

    my($path_info) = $q->path_info();
    $path_info =~ s,^.*/,,;

    print $q->header(-type => "$mime; filename=\"$path_info\"",
                     -content_disposition =>
                     "filename=$path_info",
                     -last_modified => http_date($time));
}

sub get_browser_endl($)
{
    my($ua) = @_;
    my $endl;

    if ($ua =~ /^Mozilla\/[1-4]/)
    {
	if ($ua =~ /compatible/)
	{
	    $endl = "\015\012";
	}
	else
	{
	    $endl = "\012";	# netscape 4.x and below want unix LF only
	}
    }
    else
    {
	$endl = "\015\012";
    }

    $endl;
}

########################################################################
# Yahoo! Calendar link
########################################################################

sub yahoo_calendar_link($$)
{
    my($event,$city_descr) = @_;

    my($subj) = $event->[$Hebcal::EVT_IDX_SUBJ];

    my($min) = $event->[$Hebcal::EVT_IDX_MIN];
    my($hour) = $event->[$Hebcal::EVT_IDX_HOUR];
    $hour -= 12 if $hour > 12;

    my($year) = $event->[$Hebcal::EVT_IDX_YEAR];
    my($mon) = $event->[$Hebcal::EVT_IDX_MON] + 1;
    my($mday) = $event->[$Hebcal::EVT_IDX_MDAY];

    my($desc);

    my($ST) = sprintf("%04d%02d%02d", $year, $mon, $mday);
    if ($event->[$Hebcal::EVT_IDX_UNTIMED] == 0)
    {
	$desc = (defined $city_descr && $city_descr ne '') ?
	    "in $city_descr" : '';
	$desc =~ s/\s*&nbsp;\s*/ /g;

	$ST .= sprintf("T%02d%02d00",
		       ($hour < 12 && $hour > 0) ? $hour + 12 : $hour,
		       $min);

#  	if ($q->param('tz') ne '')
#  	{
#  	    my($abstz) = ($q->param('tz') >= 0) ?
#  		$q->param('tz') : -$q->param('tz');
#  	    my($signtz) = ($q->param('tz') < 0) ? '-' : '';

#  	    $ST .= sprintf("Z%s%02d00", $signtz, $abstz);
#  	}

	$ST .= "&amp;DUR=00" . $event->[$Hebcal::EVT_IDX_DUR];
    }
    else
    {
	$desc = (Hebcal::get_holiday_anchor($subj,undef,undef))[2];
    }

    $ST .= "&amp;DESC=" . &url_escape($desc)
	if $desc ne '';

    "http://calendar.yahoo.com/?v=60&amp;TYPE=16&amp;ST=$ST&amp;TITLE=" .
	&url_escape($subj) . "&amp;VIEW=d";
}

sub macintosh_datebook($$)
{
    my($q, $events) = @_;
    my($numEntries) = scalar(@{$events});

    export_http_header($q, 'text/tab-separated-values');

    for (my $i = 0; $i < $numEntries; $i++)
    {
	my $date = 
	    $Hebcal::MoY_long{$events->[$i]->[$Hebcal::EVT_IDX_MON] + 1} .
	    ' ' .  $events->[$i]->[$Hebcal::EVT_IDX_MDAY] . ', ' .
	    $events->[$i]->[$Hebcal::EVT_IDX_YEAR];

	my $start_time = '';
	my $end_time = '';
	my $end_date = $date;
	my $memo = '';

	if ($events->[$i]->[$Hebcal::EVT_IDX_UNTIMED] == 0)
	{
	    my($hour) = $events->[$i]->[$Hebcal::EVT_IDX_HOUR];
	    my($min) = $events->[$i]->[$Hebcal::EVT_IDX_MIN];

	    $hour -= 12 if $hour > 12;
	    $start_time = sprintf("%d:%02d PM", $hour, $min);

	    $hour += 12 if $hour < 12;
	    $min += $events->[$i]->[$Hebcal::EVT_IDX_DUR];

	    if ($min >= 60)
	    {
		$hour++;
		$min -= 60;
	    }

	    $hour -= 12 if $hour > 12;
	    $end_time = sprintf("%d:%02d PM", $hour, $min);
	    $end_date = '';
	    $memo = '';
	}

	# this is BROKEN
	# general format is
	# Hanukkah<B8>December 14, 1998<B8>December 14, 1998<B8><B8><B8>Jewish Holiday<B8><9B>
	# Doc group mtg<B8>August 21, 2002<B8><B8>2:00 PM<B8>3:00 PM<B8><B8><9B>

	print STDOUT join("\t",
			  $events->[$i]->[$Hebcal::EVT_IDX_SUBJ],
			  $date, $end_date,
			  $start_time, $end_time,
			  $memo,
			  ), "\015";
    }

    1;
}

########################################################################
# export to vCalendar
########################################################################

sub vcalendar_write_contents($$$$$)
{
    my($q,$events,$tz,$state,$title) = @_;

    my $is_icalendar = ($q->path_info() =~ /\.ics$/) ? 1 : 0;

    if ($is_icalendar) {
	export_http_header($q, 'text/calendar; charset=UTF-8');
    } else {
	export_http_header($q, 'text/x-vCalendar');
    }

    my $endl = get_browser_endl($q->user_agent());

    my $tzid;
    $tz = 0 unless defined $tz;

    if ($is_icalendar) {
    if (defined $state) {
	if ($state eq 'AK') {
	    if ($tz == -10) {
		$tzid = 'US/Aleutian';
	    } else {
		$tzid = 'US/Alaska';
	    }
	} elsif ($state eq 'AZ') {
	    $tzid = 'US/Arizona';
	} elsif ($state eq 'HI') {
	    $tzid = 'US/Hawaii';
	} elsif ($state eq 'IN') {
	    # TODO: figure out which one of these to use
	    $tzid = 'US/East-Indiana';
	    $tzid = 'US/Indiana-Starke';
	} elsif ($state eq 'MI') {
	    $tzid = 'US/Michigan';
	} elsif ($tz == -5) {
	    $tzid = 'US/Eastern';
	} elsif ($tz == -6) {
	    $tzid = 'US/Central';
	} elsif ($tz == -7) {
	    $tzid = 'US/Mountain';
	} elsif ($tz == -8) {
	    $tzid = 'US/Pacific';
	} elsif ($tz == -9) {
	    $tzid = 'US/Alaska';
	} elsif ($tz == -10) {
	    $tzid = 'US/Hawaii';
	} else {
	    $tzid = 'US/Unknown';
	}
    } elsif ($tz == -5) {
	$tzid = 'US/Eastern';
    } elsif ($tz == -6) {
	$tzid = 'US/Central';
    } elsif ($tz == -7) {
	$tzid = 'US/Mountain';
    } elsif ($tz == -8) {
	$tzid = 'US/Pacific';
    } elsif ($tz == -9) {
	$tzid = 'US/Alaska';
    } elsif ($tz == -10) {
	$tzid = 'US/Hawaii';
    }
    }

    my $dtstamp = strftime("%Y%m%dT%H%M%SZ", gmtime(time()));

    print STDOUT qq{BEGIN:VCALENDAR$endl};

    if ($is_icalendar) {
	print STDOUT qq{VERSION:2.0$endl},
	qq{X-WR-CALNAME:Hebcal $title$endl},
	qq{PRODID:-//hebcal.com/NONSGML Hebcal Calendar v$VERSION//EN$endl};
    } else {
	print STDOUT qq{VERSION:1.0$endl};
    }

    print STDOUT qq{METHOD:PUBLISH$endl};

    if ($tzid) {
	print STDOUT qq{X-WR-TIMEZONE;VALUE=TEXT:$tzid$endl};
    }

    my($i);
    my($numEntries) = scalar(@{$events});
    for ($i = 0; $i < $numEntries; $i++)
    {
	print STDOUT qq{BEGIN:VEVENT$endl};
	print STDOUT qq{DTSTAMP:$dtstamp$endl};

	if ($is_icalendar) {
	    print STDOUT qq{CATEGORIES:Holidays$endl};
	} else {
	    print STDOUT qq{CATEGORIES:HOLIDAY$endl};
	}

	my $subj = $events->[$i]->[$Hebcal::EVT_IDX_SUBJ];

	my($href,$hebrew,$dummy_memo) = Hebcal::get_holiday_anchor($subj,0,$q);

	$subj =~ s/,/\\,/g;

	if ($is_icalendar && $hebrew &&
	    defined $q->param('heb') && $q->param('heb') =~ /^on|1$/) {
	    $subj .= " / $hebrew";
	}

	print STDOUT qq{CLASS:PUBLIC$endl}, qq{SUMMARY:$subj$endl};

	if ($is_icalendar && $href) {
	    if ($href =~ /\.html$/) {
		$href .= "?tag=ical";
	    }
	    print STDOUT qq{URL;VALUE=URI:$href$endl};
	}

 	if ($events->[$i]->[$Hebcal::EVT_IDX_MEMO])
 	{
 	    my $memo = $events->[$i]->[$Hebcal::EVT_IDX_MEMO];
 	    $memo =~ s/,/\\,/g;

 	    if ($memo =~ /^in (.+)\s*$/)
 	    {
 		print STDOUT qq{LOCATION:$1$endl};
 	    }
 	    else
 	    {
 		print STDOUT qq{DESCRIPTION:},
 		$memo, $endl;
 	    }
	}

	my($date) = sprintf("%04d%02d%02d",
			    $events->[$i]->[$Hebcal::EVT_IDX_YEAR],
			    $events->[$i]->[$Hebcal::EVT_IDX_MON] + 1,
			    $events->[$i]->[$Hebcal::EVT_IDX_MDAY],
			    );
	my($end_date) = $date;

	if ($events->[$i]->[$Hebcal::EVT_IDX_UNTIMED] == 0)
	{
	    my($hour) = $events->[$i]->[$Hebcal::EVT_IDX_HOUR];
	    my($min) = $events->[$i]->[$Hebcal::EVT_IDX_MIN];

	    $hour += 12 if $hour < 12;
	    $date .= sprintf("T%02d%02d00", $hour, $min);

	    $min += $events->[$i]->[$Hebcal::EVT_IDX_DUR];
	    if ($min >= 60)
	    {
		$hour++;
		$min -= 60;
	    }

	    $end_date .= sprintf("T%02d%02d00", $hour, $min);
	}
	else
	{
	    my($gy,$gm,$gd) = Date::Calc::Add_Delta_Days
		($events->[$i]->[$Hebcal::EVT_IDX_YEAR],
		 $events->[$i]->[$Hebcal::EVT_IDX_MON] + 1,
		 $events->[$i]->[$Hebcal::EVT_IDX_MDAY],
		 1);
	    $end_date = sprintf("%04d%02d%02d", $gy, $gm, $gd);

	    # for vCalendar Palm Desktop and Outlook 2000 seem to
	    # want midnight to midnight for all-day events.
	    # Midnight to 23:59:59 doesn't seem to work as expected.
	    if (!$is_icalendar)
	    {
		$date .= "T000000";
		$end_date .= "T000000";
	    }
	}

	print STDOUT qq{DTSTART};
	print STDOUT ";TZID=$tzid" if $tzid;
	print STDOUT qq{:$date$endl};

	if ($is_icalendar && $events->[$i]->[$Hebcal::EVT_IDX_UNTIMED])
	{
	    # avoid using DTEND since Apple iCal and Lotus Notes
	    # seem to interpret all-day events differently
	    print STDOUT qq{DURATION:P1D$endl};
	}
	else
	{
	    print STDOUT qq{DTEND};
	    print STDOUT ";TZID=$tzid" if $tzid;
	    print STDOUT qq{:$end_date$endl};
        }
	
	if ($is_icalendar) {
	    my $subj_copy = lc($subj);
	    $subj_copy =~ s/[^\w]/-/g;
	    $subj_copy =~ s/-+/-/g;
	    $subj_copy =~ s/-$//g;

	    my $date_copy = $date;
	    $date_copy =~ s/T\d+$//;

	    my $uid = $subj_copy . '-' . $date_copy;

	    if ($events->[$i]->[$Hebcal::EVT_IDX_MEMO] &&
		$events->[$i]->[$Hebcal::EVT_IDX_MEMO] =~ /^in (.+)\s*$/) {
		my $loc = lc($1);
		$loc =~ s/[^\w]/-/g;
		$loc =~ s/-+/-/g;
		$loc =~ s/-$//g;

		$uid .= '-' . $loc;
	    }

	    $uid .= '@hebcal.com';

	    print STDOUT qq{UID:$uid$endl};
	    print STDOUT qq{ORGANIZER:mailto:nobody\@hebcal.com$endl};
	}

	print STDOUT qq{END:VEVENT$endl};
    }

    print STDOUT qq{END:VCALENDAR$endl};

    1;
}


########################################################################
# export to Outlook CSV
########################################################################

sub csv_write_contents($$$)
{
    my($q,$events,$euro) = @_;
    my($numEntries) = scalar(@{$events});

    export_http_header($q, 'text/x-csv');
    my $endl = get_browser_endl($q->user_agent());

    print STDOUT
	qq{"Subject","Start Date","Start Time","End Date",},
	qq{"End Time","All day event","Description","Show time as",},
	qq{"Location"$endl};

    my($i);
    for ($i = 0; $i < $numEntries; $i++)
    {
	my($subj) = $events->[$i]->[$Hebcal::EVT_IDX_SUBJ];
	my($memo) = $events->[$i]->[$Hebcal::EVT_IDX_MEMO];

	my $date;
	if ($euro) {
	    $date = sprintf("\"%d/%d/%04d\"",
			    $events->[$i]->[$Hebcal::EVT_IDX_MDAY],
			    $events->[$i]->[$Hebcal::EVT_IDX_MON] + 1,
			    $events->[$i]->[$Hebcal::EVT_IDX_YEAR]);
	} else {
	    $date = sprintf("\"%d/%d/%04d\"",
			    $events->[$i]->[$Hebcal::EVT_IDX_MON] + 1,
			    $events->[$i]->[$Hebcal::EVT_IDX_MDAY],
			    $events->[$i]->[$Hebcal::EVT_IDX_YEAR]);
	}

	my($start_time) = '';
	my($end_time) = '';
	my($end_date) = '';
	my($all_day) = '"true"';

	if ($events->[$i]->[$Hebcal::EVT_IDX_UNTIMED] == 0)
	{
	    my($hour) = $events->[$i]->[$Hebcal::EVT_IDX_HOUR];
	    my($min) = $events->[$i]->[$Hebcal::EVT_IDX_MIN];

	    $hour -= 12 if $hour > 12;
	    $start_time = sprintf("\"%d:%02d PM\"", $hour, $min);

	    $hour += 12 if $hour < 12;
	    $min += $events->[$i]->[$Hebcal::EVT_IDX_DUR];

	    if ($min >= 60)
	    {
		$hour++;
		$min -= 60;
	    }

	    $hour -= 12 if $hour > 12;
	    $end_time = sprintf("\"%d:%02d PM\"", $hour, $min);
	    $end_date = $date;
	    $all_day = '"false"';
	}

	$subj =~ s/,//g;
	$memo =~ s/,//g;

	$subj =~ s/\"/''/g;
	$memo =~ s/\"/''/g;

	my $loc = 'Jewish Holidays';
	if ($memo =~ /^in (.+)/)
	{
	    $memo = '';
	    $loc = $1;
	}

	print STDOUT
	    qq{"$subj",$date,$start_time,$end_date,$end_time,},
	    qq{$all_day,"$memo",};

	if ($events->[$i]->[$Hebcal::EVT_IDX_UNTIMED] == 0 ||
	    $events->[$i]->[$Hebcal::EVT_IDX_YOMTOV] == 1)
	{
	    print STDOUT qq{"4"};
	}
	else
	{
	    print STDOUT qq{"3"};
	}

	print STDOUT qq{,"$loc"$endl};
    }

    1;
}

########################################################################
# for managing email shabbat list
########################################################################

sub sendmail_v2($$$)
{
    my($return_path,$headers,$body,$warn) = @_;

    use Email::Valid;
    use Net::SMTP;
    
    if (! Email::Valid->address($return_path))
    {
	warn "Hebcal.pm: Return-Path $return_path is invalid"
	    if $warn;
	return 0;
    }

    my($from) = $headers->{'From'};
    if (!$from || ! Email::Valid->address($from))
    {
	warn "Hebcal.pm: From $from is invalid"
	    if $warn;
	return 0;
    }

    my(%recipients);
    foreach my $hdr ('To', 'Cc', 'Bcc')
    {
	if (defined $headers->{$hdr})
	{
	    foreach my $addr (split(/\s*,\s*/, $headers->{$hdr}))
	    {
		next unless $addr;
		next unless Email::Valid->address($addr);
		$recipients{Email::Valid->address($addr)} = 1;
	    }
	}
    }

    if (! keys %recipients)
    {
	warn "Hebcal.pm: no recipients!"
	    if $warn;
	return 0;
    }

    my($smtp) = Net::SMTP->new('mail.hebcal.com', Timeout => 20);
    unless ($smtp) {
        return 0;
    }

    my $message = '';
    while (my($key,$val) = each %{$headers})
    {
	next if lc($key) eq 'bcc';
	while (chomp($val)) {}
	$message .= "$key: $val\n";
    }

    my $hostname = `/bin/hostname -f`;
    chomp($hostname);

    if (! defined $headers->{'X-Sender'})
    {
	my($login) = getlogin() || getpwuid($<) || "UNKNOWN";
	$message .= "X-Sender: $login\@$hostname\n";
    }

    if (! defined $headers->{'X-Mailer'})
    {
	$message .= "X-Mailer: hebcal mail v$VERSION\n";
    }

    if (! defined $headers->{'Message-ID'})
    {
	$message .= "Message-ID: <HEBCAL.$VERSION." . time() . ".$$\@$hostname>\n";
    }

    $message .= "\n" . $body;

    my @recip = keys %recipients;

    unless ($smtp->mail($return_path)) {
        warn "smtp mail() failure for @recip\n"
	    if $warn;
        return 0;
    }
    foreach (@recip) {
	next unless $_;
        unless($smtp->to($_)) {
            warn "smtp to() failure for $_\n"
		if $warn;
            return 0;
        }
    }
    unless($smtp->data()) {
        warn "smtp data() failure for @recip\n"
	    if $warn;
        return 0;
    }
    unless($smtp->datasend($message)) {
        warn "smtp datasend() failure for @recip\n"
	    if $warn;
        return 0;
    }
    unless($smtp->dataend()) {
        warn "smtp dataend() failure for @recip\n"
	    if $warn;
        return 0;
    }
    unless($smtp->quit) {
        warn "smtp quit failure for @recip\n"
	    if $warn;
        return 0;
    }

    1;
}


########################################################################
# imported from Sadinoff's Hebcal.pm
########################################################################

my $NISAN = 1;
my $IYYAR = 2;
my $SIVAN = 3;
my $TAMUZ = 4;
my $AV = 5;
my $ELUL = 6;
my $TISHREI = 7;
my $CHESHVAN = 8;
my $KISLEV = 9;
my $TEVET = 10;
my $SHVAT = 11;
my $ADAR_I = 12;
my $ADAR_II = 13;

sub MONTHS_IN_HEB ($) {
    LEAP_YR_HEB($_[0]) ? 13 :12;
}

sub LEAP_YR_HEB ($) {
    (1 + ($_[0] * 7)) % 19 < 7 ? 1 : 0;
}

sub max_days_in_heb_month ($$) {
    my($month,$year) = @_;

    if ($month == $IYYAR || $month == $TAMUZ ||
	$month == $ELUL || $month == $TEVET ||
	$month == $ADAR_II ||
	($month == $ADAR_I && !LEAP_YR_HEB($year)) ||
	($month == $CHESHVAN && !long_cheshvan($year)) ||
	($month == $KISLEV && short_kislev($year)))
    {
	return 29;
    }
    else
    {
	return 30;
    }
}


sub greg2hebrew ($$$) {
    my($gregy,$gregm,$gregd) = @_;

    my $d = Date::Calc::Date_to_Days($gregy,$gregm,$gregd);
    my @mmap = (9,10,11,12,1,2,3,4,7,7,7,8);

    my $month = $mmap[$gregm - 1];
    my $year = 3760 + $gregy;

    my $hebdate = {dd => 1, mm => 7, yy => $year + 1};
    while ($d >= hebrew2abs($hebdate)) {
	$year++;
	$hebdate->{yy} = $year + 1,
    }

    while ($hebdate->{mm} = $month,
	   $hebdate->{dd} = max_days_in_heb_month($month,$year),
	   $hebdate->{yy} = $year,
	   $d > hebrew2abs($hebdate)) {
	$month = ($month % MONTHS_IN_HEB($year)) + 1;
    }

    $hebdate->{dd} = 1;

    my $day = int($d - hebrew2abs($hebdate) + 1);
    $hebdate->{dd} = $day;

    return $hebdate;
}

# Days from sunday prior to start of hebrew calendar to mean
# conjunction of tishrei in hebrew YEAR 
#  
sub hebrew_elapsed_days ($) {
    my $year = shift;

    my $yearl = $year;
    my $m_elapsed = (235 * int(($yearl - 1) / 19) +
		     12 * (($yearl - 1) % 19) +
		     int((((($yearl - 1) % 19) * 7) + 1) / 19));
    
    my $p_elapsed = 204 + (793 * ($m_elapsed % 1080));
    
    my $h_elapsed = (5 + (12 * $m_elapsed) +
		     793 * int ($m_elapsed / 1080) +
		     int($p_elapsed / 1080));
    
    my $parts = ($p_elapsed % 1080) + 1080 * ($h_elapsed % 24);
    
    my $day = 1 + 29 * $m_elapsed + int($h_elapsed / 24);
    my $alt_day;

    if (($parts >= 19440) ||
	((2 == ($day % 7)) && ($parts >= 9924) && !(LEAP_YR_HEB($year))) ||
	((1 == ($day % 7)) && ($parts >= 16789) && LEAP_YR_HEB($year - 1))) {
	$alt_day = $day + 1;}
    else{
	$alt_day = $day;}
    
    if (($alt_day % 7) == 0 ||
	($alt_day % 7) == 3 ||
	($alt_day % 7) == 5) {
	return $alt_day + 1;
    }
    else{
	return $alt_day;
    }
}


# convert hebrew date to absolute date 
# Absolute date of Hebrew DATE.
#    The absolute date is the number of days elapsed since the (imaginary)
#    Gregorian date Sunday, December 31, 1 BC. 
sub hebrew2abs ($) {
    my $d = shift;
    my $m;
    my $tempabs = $d->{dd};

    # FIX: These loops want to be optimized with table-lookup
    if ($d->{mm} < $TISHREI) {
	for ($m = $TISHREI; $m <= MONTHS_IN_HEB($d->{yy}); $m++) {
	    $tempabs +=  max_days_in_heb_month($m, $d->{yy});
	}
	
	for ($m = $NISAN; $m < $d->{mm}; $m++) {
	    $tempabs +=  max_days_in_heb_month($m, $d->{yy});
	}
    }
    else {
	for ($m = $TISHREI; $m < $d->{mm}; $m++) {
	    $tempabs +=  max_days_in_heb_month($m, $d->{yy});
	}
    }
    my $days = hebrew_elapsed_days($d->{yy}) - 1373429 + $tempabs;
#    croak Dumper($d)if $days < 0;
    return $days;
}

# Number of days in the hebrew YEAR 
sub days_in_heb_year ($) {
    my $year = shift;
    return hebrew_elapsed_days($year + 1) - hebrew_elapsed_days($year);
}

# true if Cheshvan is long in hebrew YEAR 
sub long_cheshvan ($) {
    (days_in_heb_year($_[0]) % 10) == 5;
}

# true if Cheshvan is long in hebrew YEAR 
sub short_kislev ($) {
    (days_in_heb_year($_[0]) % 10) == 3;
}



# avoid warnings
if ($^W && 0)
{
    $_ = $Hebcal::tz_names{'foo'};
    $_ = $Hebcal::city_tz{'foo'};
    $_ = $Hebcal::city_dst{'foo'};
    $_ = $Hebcal::MoY_long{'foo'};
    $_ = $Hebcal::ashk2seph{'foo'};
}

1;
