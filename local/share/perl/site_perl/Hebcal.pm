########################################################################
# Hebcal Interactive Jewish Calendar is a web site that lets you
# generate a list of Jewish holidays for any year. Candle lighting
# times are calculated from your latitude and longitude (which can
# be determined by your zip code or closest city).
#
# Copyright (c) 2015 Michael J. Radwin.
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

use strict;
use utf8;
use POSIX qw(strftime);
use lib "/home/hebcal/local/share/perl";
use lib "/home/hebcal/local/share/perl/site_perl";
use Date::Calc ();
use Time::Local ();		# needed for Hebcal::event_to_time
use URI::Escape;
use HebcalConst;
use Digest::MD5 ();
use HebcalGPL;

our $eval_use_DBI;
my $eval_use_DateTime;
our $eval_use_JSON;

if ($^V && $^V ge v5.8.1) {
    binmode(STDOUT, ":utf8");
}

########################################################################
# constants
########################################################################

our $WEBDIR = $ENV{"DOCUMENT_ROOT"} || "/var/www";
our $HEBCAL_BIN = "$WEBDIR/bin/hebcal";
our $LUACH_SQLITE_FILE = "$WEBDIR/hebcal/luach.sqlite3";
our $CONFIG_INI_PATH = "/home/hebcal/local/etc/hebcal-dot-com.ini";

my $ZIP_SQLITE_FILE = "$WEBDIR/hebcal/zips.sqlite3";
our $GEONAME_SQLITE_FILE = "$WEBDIR/hebcal/geonames.sqlite3";

my $CONFIG_INI;
my $HOSTNAME;

# boolean options
our @opts = qw(c o s i a d D F);
our $havdalah_min = 50;

our @DoW = qw(Sun Mon Tue Wed Thu Fri Sat);
our @DoW_long = qw(Sunday Monday Tuesday Wednesday Thursday Friday Saturday);
our @MoY_short = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
our @MoY_hebrew = (
     "יָנוּאָר",
     "פֶבְּרוּאָר",
     "מֶרְץ",
     "אַפְּרִיל",
     "מַאי",
     "יוּנִי",
     "יוּלִי",
     "אוֹגוּסְט",
     "סֶפְּטֶמְבֶּר",
     "אוֹקְטוֹבֶּר",
     "נוֹבֶמְבֶּר",
     "דֶּצֶמְבֶּר",
    );
our %MoY_long = (
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

our %lang_names =
    (
     "s"  => "Sephardic transliterations",
     "sh" => "Sephardic translit. + Hebrew",
     "a"  => "Ashkenazis transliterations",
     "ah" => "Ashkenazis translit. + Hebrew",
     "h"  => "Hebrew only",
     );

our %CONTINENTS =
    (
     'AF' => 'Africa',
     'AS' => 'Asia',
     'EU' => 'Europe',
     'NA' => 'North America',
     'SA' => 'South America',
     'OC' => 'Oceania',
     'AN' => 'Antarctica',
    );

our %CITIES_OLD = (
'Ashdod' => 'IL-Ashdod',
'Atlanta' => 'US-Atlanta-GA',
'Austin' => 'US-Austin-TX',
'Baghdad' => 'IQ-Baghdad',
'Beer Sheva' => 'IL-Beer Sheva',
'Berlin' => 'DE-Berlin',
'Baltimore' => 'US-Baltimore-MD',
'Bogota' => 'CO-Bogota',
'Boston' => 'US-Boston-MA',
'Buenos Aires' => 'AR-Buenos Aires',
'Buffalo' => 'US-Buffalo-NY',
'Chicago' => 'US-Chicago-IL',
'Cincinnati' => 'US-Cincinnati-OH',
'Cleveland' => 'US-Cleveland-OH',
'Dallas' => 'US-Dallas-TX',
'Denver' => 'US-Denver-CO',
'Detroit' => 'US-Detroit-MI',
'Eilat' => 'IL-Eilat',
'Gibraltar' => 'GI-Gibraltar',
'Haifa' => 'IL-Haifa',
'Hawaii' => 'US-Honolulu-HI',
'Houston' => 'US-Houston-TX',
'Jerusalem' => 'IL-Jerusalem',
'Johannesburg' => 'ZA-Johannesburg',
'Kiev' => 'UA-Kiev',
'La Paz' => 'BO-La Paz',
'Livingston' => 'US-Livingston-NY',
'London' => 'GB-London',
'Los Angeles' => 'US-Los Angeles-CA',
'Miami' => 'US-Miami-FL',
'Melbourne' => 'AU-Melbourne',
'Mexico City' => 'MX-Mexico City',
'Montreal' => 'CA-Montreal',
'Moscow' => 'RU-Moscow',
'New York' => 'US-New York-NY',
'Omaha' => 'US-Omaha-NE',
'Ottawa' => 'CA-Ottawa',
'Panama City' => 'PA-Panama City',
'Paris' => 'FR-Paris',
'Petach Tikvah' => 'IL-Petach Tikvah',
'Philadelphia' => 'US-Philadelphia-PA',
'Phoenix' => 'US-Phoenix-AZ',
'Pittsburgh' => 'US-Pittsburgh-PA',
'Saint Louis' => 'US-Saint Louis-MO',
'Saint Petersburg' => 'RU-Saint Petersburg',
'San Francisco' => 'US-San Francisco-CA',
'Seattle' => 'US-Seattle-WA',
'Sydney' => 'AU-Sydney',
'Tel Aviv' => 'IL-Tel Aviv',
'Tiberias' => 'IL-Tiberias',
'Toronto' => 'CA-Toronto',
'Vancouver' => 'CA-Vancouver',
'White Plains' => 'US-White Plains-NY',
'Washington DC' => 'US-Washington-DC',
'IL-Bene Beraq' => 'IL-Bnei Brak',
);

# based on cities.txt and loaded into HebcalConst.pm
our %CITY_TZID = ();
our %CITY_COUNTRY = ();
our %CITY_LATLONG = ();
while(my($id,$info) = each(%HebcalConst::CITIES_NEW)) {
    my($country,$city,$latitude,$longitude,$tzName,$woeid) = @{$info};
    $CITY_TZID{$id} = $tzName;
    $CITY_COUNTRY{$id} = $country;
    $CITY_LATLONG{$id} = [$latitude,$longitude];
}

# translate from Askenazic transiliterations to Separdic
our %ashk2seph =
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
  "Purim Koton"			=>	"Purim Katan",
  "Ta'anis Bechoros"		=>	"Ta'anit Bechorot",

  # special shabbatot
  "Shabbas Shuvah"		=>	"Shabbat Shuva",
  "Shabbas Shekalim"		=>	"Shabbat Shekalim",
  "Shabbas Zachor"		=>	"Shabbat Zachor",
  "Shabbas Parah"		=>	"Shabbat Parah",
  "Shabbas HaChodesh"		=>	"Shabbat HaChodesh",
  "Shabbas HaGadol"		=>	"Shabbat HaGadol",
  "Shabbas Chazon"		=>	"Shabbat Chazon",
  "Shabbas Nachamu"		=>	"Shabbat Nachamu",
  "Shabbos Shuvah"		=>	"Shabbat Shuva",
  "Shabbos Shekalim"		=>	"Shabbat Shekalim",
  "Shabbos Zachor"		=>	"Shabbat Zachor",
  "Shabbos Parah"		=>	"Shabbat Parah",
  "Shabbos HaChodesh"		=>	"Shabbat HaChodesh",
  "Shabbos HaGadol"		=>	"Shabbat HaGadol",
  "Shabbos Chazon"		=>	"Shabbat Chazon",
  "Shabbos Nachamu"		=>	"Shabbat Nachamu",
  );


my %DAFYOMI = (
   "Berachot" => "Berakhot",
   "Shabbat" => 0,
   "Eruvin" => 0,
   "Pesachim" => 0,
   "Shekalim" => 0,
   "Yoma" => 0,
   "Sukkah" => 0,
   "Beitzah" => 0,
   "Rosh Hashana" => "Rosh Hashanah",
   "Taanit" => 0,
   "Megillah" => 0,
   "Moed Katan" => 0,
   "Chagigah" => 0,
   "Yevamot" => 0,
   "Ketubot" => 0,
   "Nedarim" => 0,
   "Nazir" => 0,
   "Sotah" => 0,
   "Gitin" => "Gittin",
   "Kiddushin" => 0,
   "Baba Kamma" => "Bava Kamma",
   "Baba Metzia" => "Bava Metzia",
   "Baba Batra" =>  "Bava Batra",
   "Sanhedrin" => 0,
   "Makkot" => 0,
   "Shevuot" => 0,
   "Avodah Zarah" => 0,
   "Horayot" => 0,
   "Zevachim" => 0,
   "Menachot" => 0,
   "Chullin" => 0,
   "Bechorot" => "Bekhorot",
   "Arachin" => "Arakhin",
   "Temurah" => 0,
   "Keritot" => 0,
   "Meilah" => 0,
   "Kinnim" => 0,
   "Tamid" => 0,
   "Midot" => "Middot",
   "Niddah" => 0,
);

# @events is an array of arrays.  these are the indices into each
# event structure:

our $EVT_IDX_SUBJ = 0;		# title of event
our $EVT_IDX_UNTIMED = 1;		# 0 if all-day, non-zero if timed
our $EVT_IDX_MIN = 2;		# minutes, [0 .. 59]
our $EVT_IDX_HOUR = 3;		# hour of day, [0 .. 23]
our $EVT_IDX_MDAY = 4;		# day of month, [1 .. 31]
our $EVT_IDX_MON = 5;		# month of year, [0 .. 11]
our $EVT_IDX_YEAR = 6;		# year [1 .. 9999]
our $EVT_IDX_DUR = 7;		# duration in minutes
our $EVT_IDX_MEMO = 8;		# memo text
our $EVT_IDX_YOMTOV = 9;		# is the holiday Yom Tov?

my %num2heb =
(
 1	=> "\x{5D0}",
 2	=> "\x{5D1}",
 3	=> "\x{5D2}",
 4	=> "\x{5D3}",
 5	=> "\x{5D4}",
 6	=> "\x{5D5}",
 7	=> "\x{5D6}",
 8	=> "\x{5D7}",
 9	=> "\x{5D8}",
 10	=> "\x{5D9}",
 20	=> "\x{5DB}",
 30	=> "\x{5DC}",
 40	=> "\x{5DE}",
 50	=> "\x{5E0}",
 60	=> "\x{5E1}",
 70	=> "\x{5E2}",
 80	=> "\x{5E4}",
 90	=> "\x{5E6}",
 100	=> "\x{5E7}",
 200	=> "\x{5E8}",
 300	=> "\x{5E9}",
 400	=> "\x{5EA}",
);

my %monthnames =
    (
     "Nisan"	=> "\x{5E0}\x{5B4}\x{5D9}\x{5E1}\x{5B8}\x{5DF}",
     "Iyyar"	=> "\x{5D0}\x{5B4}\x{5D9}\x{5B8}\x{5D9}\x{5E8}",
     "Sivan"	=> "\x{5E1}\x{5B4}\x{5D9}\x{5D5}\x{5B8}\x{5DF}",
     "Tamuz"	=> "\x{5EA}\x{5BC}\x{5B8}\x{5DE}\x{5D5}\x{5BC}\x{5D6}",
     "Av"	=> "\x{5D0}\x{5B8}\x{5D1}",
     "Elul"	=> "\x{5D0}\x{5B1}\x{5DC}\x{5D5}\x{5BC}\x{5DC}",
     "Tishrei"	=> "\x{5EA}\x{5BC}\x{5B4}\x{5E9}\x{5C1}\x{5B0}\x{5E8}\x{5B5}\x{5D9}",
     "Cheshvan"	=> "\x{5D7}\x{5B6}\x{5E9}\x{5C1}\x{5B0}\x{5D5}\x{5B8}\x{5DF}",
     "Kislev"	=> "\x{5DB}\x{5BC}\x{5B4}\x{5E1}\x{5B0}\x{5DC}\x{5B5}\x{5D5}",
     "Tevet"	=> "\x{5D8}\x{5B5}\x{5D1}\x{5B5}\x{5EA}",
     "Sh'vat"	=> "\x{5E9}\x{5C1}\x{5B0}\x{5D1}\x{5B8}\x{5D8}",
     "Adar"	=> "\x{5D0}\x{5B7}\x{5D3}\x{5B8}\x{5E8}",
     "Adar I"	=> "\x{5D0}\x{5B7}\x{5D3}\x{5B8}\x{5E8} \x{5D0}\x{5F3}",
     "Adar II"	=> "\x{5D0}\x{5B7}\x{5D3}\x{5B8}\x{5E8} \x{5D1}\x{5F3}",
     );

my %monthnames_inprefix = (
    "Iyyar"     => "בְּאִיָּר",
    "Tamuz"     => "בְּתַמּוּז",
    "Elul"      => "בֶּאֱלוּל",
    "Tishrei"   => "בְּתִשְׁרֵי",
    "Kislev"    => "בְּכִסְלֵו",
    "Sh'vat"    => "בִּשְׁבָט",
    "Adar"      => "בַּאֲדָר",
    "Adar I"    => "בַּאֲדָר א׳",
    "Adar II"   => "בַּאֲדָר ב׳",
);

my $ZONE_TAB = "/usr/share/zoneinfo/zone.tab";
my @TIMEZONES;
my $TIMEZONE_LIST_INIT;

sub get_timezones {
    if (!$TIMEZONE_LIST_INIT) {
        open(ZONE_TAB, $ZONE_TAB) || die "$ZONE_TAB: $!";
        my @zones;
        while(<ZONE_TAB>) {
            chomp;
            next if /^\#/;
            my($country,$latlong,$tz,$comments) = split(/\s+/, $_, 4);
            push(@zones, $tz);
        }
        close(ZONE_TAB);
        @TIMEZONES = sort @zones;
        unshift(@TIMEZONES, "UTC");
        $TIMEZONE_LIST_INIT = 1;
    }
    \@TIMEZONES;
}

sub is_timezone_valid {
    my($tzid) = @_;
    my $timezones = get_timezones();
    foreach my $tz (@{$timezones}) {
        return 1 if $tzid eq $tz;
    }
    return 0;
}

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
	$hour += 12 unless $hour == 0;	# timed events are always evening
					# except for midnight
        $dur = 1;
	$untimed = 0;
    }
    else
    {
	$hour = $min = -1;
	$dur = 0;
	$untimed = 1;
	$subj = $descr;
	$subj =~ s/Channukah/Chanukah/; # make spelling consistent
	$subj =~ s/Purim Koson/Purim Koton/;
	$subj =~ s/Tu B\'Shvat/Tu BiShvat/;
    }

    my($yomtov) = 0;
    my($subj_copy) = $subj;

    $subj_copy = $ashk2seph{$subj_copy}
	if defined $ashk2seph{$subj_copy};
    $subj_copy =~ s/ \d{4}$//; # fix Rosh Hashana

    $yomtov = 1 if $HebcalConst::YOMTOV{$subj_copy};

    $subj =~ s/\"/''/g;
    $subj =~ s/\s*:\s*$//g;

    my($mon,$mday,$year) = split(/\//, $date);

#    if (($subj eq 'Yom HaZikaron' || $subj eq "Yom HaAtzma'ut") &&
#	($year == 2004)) {
#	$mday++;
#    }

    ($subj,$untimed,$min,$hour,$mday,$mon - 1,$year,$dur,$yomtov);
}

sub format_evt_time {
    my($evt,$suffix) = @_;
    format_hebcal_event_time($evt->[$EVT_IDX_HOUR],
			     $evt->[$EVT_IDX_MIN],
			     $suffix);
}


sub format_hebcal_event_time {
    my($hour,$min,$suffix) = @_;
    $suffix = "pm" unless defined $suffix;
    if ($hour == 0) {
	$suffix =~ s/p/a/;
	$suffix =~ s/P/A/;
    }
    $hour -= 12 if $hour > 12;
    sprintf("%d:%02d%s", $hour, $min, $suffix);
}

sub get_invoke_hebcal_cache {
    my($cmd) = @_;

    # don't bother to cache if we're generating user Yahrzeit dates
    return undef if index( $cmd, " -Y" ) != -1;

    my $cmd_smashed = $cmd;
    $cmd_smashed =~ s/^\S+//;
    $cmd_smashed =~ s/\s+-([A-Za-z])/$1/g;
    $cmd_smashed =~ s/\s+//g;
    $cmd_smashed =~ s/\'//g;
    $cmd_smashed =~ s/\//_/g;

    my $hccache_dir = "/tmp/hebcal-cache/cmd";

    unless ( -d $hccache_dir ) {
        system( "/bin/mkdir", "-p", $hccache_dir );
        chmod 01777, $hccache_dir;
    }

    return "$hccache_dir/$cmd_smashed";
}

sub filter_event {
    my($subj,$no_minor_fasts,$no_special_shabbat,$no_minor_holidays,$no_modern_holidays) = @_;
    if ($no_special_shabbat || $no_minor_fasts || $no_minor_holidays || $no_modern_holidays) {
        my $subj_copy = $subj;
        $subj_copy = $ashk2seph{$subj_copy}
            if defined $ashk2seph{$subj_copy};
        my $type = $HebcalConst::HOLIDAY_TYPE{$subj_copy};
        if ($type) {
            return 1 if $no_special_shabbat && $type eq 'shabbat';
            return 1 if $no_minor_fasts && $type eq 'fast';
            return 1 if $no_minor_holidays && $type eq 'minor';
            return 1 if $no_modern_holidays && $type eq 'modern';
        }
    }
    return 0;
}


sub invoke_hebcal
{
    my($cmd,$memo,$want_sephardic,$month_filter,
        $no_minor_fasts,$no_special_shabbat,$no_minor_holidays,$no_modern_holidays) = @_;
    local($_);
    local(*HEBCAL);

    my $hccache;
    my $hccache_file = get_invoke_hebcal_cache($cmd);
    my $hccache_tmpfile = $hccache_file ? "$hccache_file.$$" : undef;

    my @events;
    if (! defined $hccache_file) {
	open(HEBCAL,"$cmd |") || die "Can't exec '$cmd': $!\n";
    } elsif (open(HEBCAL,"<$hccache_file")) {
	# will read data from cachefile, not pipe
    } else {
	open(HEBCAL,"$cmd |") || die "Can't exec '$cmd': $!\n";
	$hccache = open(HCCACHE,">$hccache_tmpfile");
    }

    my $prev = '';
    while (<HEBCAL>)
    {
	print HCCACHE $_ if $hccache;
	next if $_ eq $prev;
	$prev = $_;
	chop;

	my($date,$descr) = split(/ /, $_, 2);

	# exec hebcal with entire years, but only return events matching
	# the month requested
	if ($month_filter)
	{
	    my($mon,$mday,$year) = split(/\//, $date);
	    next if $month_filter != $mon;
	}

	my($subj,$untimed,$min,$hour,$mday,$mon,$year,$dur,$yomtov) =
	    parse_date_descr($date,$descr);

        next if filter_event($subj,$no_minor_fasts,$no_special_shabbat,$no_minor_holidays,$no_modern_holidays);

        # Suppress Havdalah when it's on same day as Candle lighting
        next if ($subj =~ /^Havdalah/ && $#events >= 0 &&
            $events[$#events]->[$EVT_IDX_MDAY] == $mday &&
            $events[$#events]->[$EVT_IDX_SUBJ] =~ /^Candle lighting/);

	next if $subj eq 'Havdalah (0 min)';

	my $memo2;
	if ($untimed) {
	    $memo2 = (get_holiday_anchor($subj,$want_sephardic,undef))[2];
	}

	push(@events, [
                $subj, $untimed,
                int($min), int($hour), int($mday), int($mon), int($year),
                $dur, ($untimed ? $memo2 : $memo), $yomtov
                ]);
    }
    close(HEBCAL);

    if ($hccache) {
        close(HCCACHE);
        my $fsize = (stat($hccache_tmpfile))[7];
        if ($fsize) {
            rename($hccache_tmpfile, $hccache_file);
        } else {
            warn "Ignoring empty cachefile $hccache_tmpfile";
            unlink($hccache_tmpfile);
        }
    }

    @events;
}

sub get_today_yomtov {
    my @events = invoke_hebcal($HEBCAL_BIN, "", 0);
    my($year,$month,$day) = Date::Calc::Today();
    for my $evt (@events) {
	if (event_date_matches($evt,$year,$month,$day) && $evt->[$EVT_IDX_YOMTOV]) {
	    return $evt->[$EVT_IDX_SUBJ];
	}
    }
    undef;
}

sub event_ymd($) {
  my($evt) = @_;
  my $year = $evt->[$EVT_IDX_YEAR];
  my $month = $evt->[$EVT_IDX_MON] + 1;
  my $day = $evt->[$EVT_IDX_MDAY];
  ($year,$month,$day);
}

sub event_dates_equal($$) {
  my($evt1,$evt2) = @_;
  my($year1,$month1,$day1) = event_ymd($evt1);
  my($year2,$month2,$day2) = event_ymd($evt2);
  $year1 == $year2 && $month1 == $month2 && $day1 == $day2;
}

sub event_date_matches($$$$) {
  my($evt,$gy,$gm,$gd) = @_;
  return ($evt->[$EVT_IDX_YEAR] == $gy
	  && $evt->[$EVT_IDX_MON] + 1 == $gm
	  && $evt->[$EVT_IDX_MDAY] == $gd);
}

sub date_format_sql($$$) {
  my($year,$month,$day) = @_;
  sprintf("%04d-%02d-%02d", $year, $month, $day);
}

sub date_format_csv($$$) {
  my($year,$month,$day) = @_;
  sprintf("%02d-%s-%04d", $day, $MoY_short[$month - 1], $year);
}

sub event_to_time
{
    my($evt) = @_;
    # holiday is at 12:00:01 am
    return Time::Local::timelocal(1,0,0,
				  $evt->[$EVT_IDX_MDAY],
				  $evt->[$EVT_IDX_MON],
				  $evt->[$EVT_IDX_YEAR] - 1900,
				  "","","");
}

sub event_tz_offset {
    my($year,$mon,$mday,$hour24,$min,$tzid) = @_;

    unless ($eval_use_DateTime) {
        eval("use DateTime");
        $eval_use_DateTime = 1;
    }

    my $dt = DateTime->new(
       year       => $year,
       month      => $mon,
       day        => $mday,
       hour       => $hour24,
       minute     => $min,
       second     => 0,
       time_zone  => $tzid,
    );

    my $tzOffset = $dt->offset();
    my $tz = int($tzOffset / 3600);
    my $tzMin = abs(int((($tzOffset / 3600) - $tz) * 60));

    sprintf("%s%02d%02d",
        $tz > 0 ? "+" : "-",
        abs($tz),
        $tzMin);
}

sub event_category {
    my($subj) = @_;

    if ($subj eq "Candle lighting" || $subj eq "No sunset today.") {
        return "candles";
    } elsif ($subj =~ /Havdalah/) {
        return "havdalah";
    } elsif ($subj =~ /^(Parshas|Parashat)\s+/) {
        return "parashat";
    } elsif ($subj =~ /^(\d+)\w+ day of the Omer$/) {
        return "omer";
    } elsif ($subj =~ /^Daf Yomi:/) {
        return "dafyomi";
    } elsif ($subj =~ /^(\d+)\w+ of ([^,]+), (\d+)$/) {
        return "hebdate";
    } else {
        return "holiday";
    }
}

sub event_to_dict {
    my($evt,$time,$url,$cfg,$q,$tzid,$ignore_tz,$dbh,$sth) = @_;

    my $subj = $evt->[$EVT_IDX_SUBJ];
    my($year,$mon,$mday) = event_ymd($evt);

    my $min = $evt->[$EVT_IDX_MIN];
    my $hour24 = $evt->[$EVT_IDX_HOUR];
    if ($evt->[$EVT_IDX_UNTIMED]) {
        $min = $hour24 = 0;
    }

    my %item;
    my $format = (defined $cfg && $cfg =~ /^[ij]$/) ?
        "%A, %d %b %Y" : "%A, %d %B %Y";
    $item{"date"} = strftime($format, localtime($time));

    my $tzOffset = $ignore_tz ? ""
        : event_tz_offset($year,$mon,$mday,$hour24,$min,$tzid);

    my $dow = $DoW[get_dow($year, $mon, $mday)];
    $item{"pubDate"} = sprintf("%s, %02d %s %d %02d:%02d:00 %s",
                           $dow,
                           $mday,
                           $MoY_short[$mon - 1],
                           $year, $hour24, $min,
                           $tzOffset);

    if ($evt->[$EVT_IDX_YOMTOV]) {
        $item{"yomtov"} = 1;
    }

    $item{"dc:date"} = sprintf("%04d-%02d-%02d", $year, $mon, $mday);
    if (!$evt->[$EVT_IDX_UNTIMED]) {
        my $tzOffset2 = $tzOffset;
        $tzOffset2 =~ s/(\d\d)$/:$1/;
        $item{"dc:date"} .= sprintf("T%02d:%02d:00%s", $hour24, $min, $tzOffset2);
    }

    my $anchor = sprintf("%04d%02d%02d_",$year,$mon,$mday) . lc($subj);
    $anchor =~ s/[^\w]/_/g;
    $anchor =~ s/_+/_/g;
    $anchor =~ s/_$//g;
    $item{"about"} = $url . "#" . $anchor;
    $item{"subj"} = $subj;
    $item{"class"} = event_category($subj);

    my($href,$hebrew,$memo) = get_holiday_anchor($subj,0,$q);
    $item{"hebrew"} = $hebrew if $hebrew;

    if ($subj eq "Candle lighting" || $subj =~ /Havdalah/)
    {
        $item{"time"} = format_evt_time($evt, "pm");
        $item{"link"} = $url . "#" . $anchor;
    }
    elsif ($subj eq "No sunset today.")
    {
        $item{"link"} = $url . "#top";
        $item{"time"} = "";
    }
    else
    {
        $item{"link"} = $href if $href;
        $item{"memo"} = $memo if $memo;
    }

    if (defined $dbh && $item{"class"} eq "parashat") {
        my $leyning0 =
            torah_calendar_memo_inner($dbh, $sth, $year, $mon, $mday);
        if ($leyning0 && $leyning0->{'T'}) {
            my $leyning = {};
            $leyning->{torah} = $leyning0->{'T'} if $leyning0->{'T'};
            $leyning->{maftir} = $leyning0->{'M'} if $leyning0->{'M'} && $leyning0->{'M'} =~ / \| /;
            $leyning->{haftarah} = $leyning0->{'H'} if $leyning0->{'H'};
            while(my($k,$v) = each(%{$leyning0})) {
                $leyning->{$k} = $v if $k =~ /^\d$/;
            }
            $item{"leyning"} = $leyning;
        }
    }

    return \%item;
}

sub events_to_dict
{
    my($events,$cfg,$q,$friday,$saturday,$tzid,$ignore_tz,$include_leyning,$israel) = @_;

    my $url = "http://" . $q->virtual_host() .
	self_url($q, {"cfg" => undef,
		      "c" => undef,
		      "nh" => undef,
		      "nx" => undef,
		      });

    $tzid ||= "UTC";

    my $dbh;
    my $sth;
    if ($include_leyning) {
        unless ($eval_use_DBI) {
            eval("use DBI");
            $eval_use_DBI = 1;
        }
        # don't raise error if we can't open DB
        $dbh = DBI->connect("dbi:SQLite:dbname=$LUACH_SQLITE_FILE", "", "");
        if (defined $dbh) {
            my $table = $israel ? "leyning_israel" : "leyning";
            $sth = $dbh->prepare("SELECT num,reading FROM $table WHERE dt = ?");
            if (!defined $sth) {
                $dbh = undef;
            }
        }
    }

    my @items;
    foreach my $evt (@{$events}) {
        my $time = event_to_time($evt);
        next if ($friday && $time < $friday);
        last if ($saturday && $time > $saturday);
        my $item = event_to_dict($evt,$time,$url,$cfg,$q,$tzid,$ignore_tz,$dbh,$sth);
        push(@items, $item);
    }

    if (defined $dbh) {
        undef $sth;
        $dbh->disconnect();
    }

    \@items;
}

sub items_to_json {
    my($items,$q,$city_descr,$latitude,$longitude,$cconfig) = @_;

    unless ($eval_use_JSON) {
	eval("use JSON");
	$eval_use_JSON = 1;
    }

    my $cb = $q->param("callback");
    if ($cb && $cb =~ /^[A-Za-z_]\w*$/) {
	print STDOUT $cb, "(";
    } else {
	$cb = undef;
    }

    my $out = { title => $city_descr,
		link => "http://" . $q->virtual_host() . self_url($q, {"cfg" => undef}),
		date => strftime("%Y-%m-%dT%H:%M:%S", gmtime(time())) . "-00:00",
		items => json_transform_items($items),
	      };

    if (defined $latitude) {
	$out->{latitude} = $latitude;
	$out->{longitude} = $longitude;
    }

    if (defined $cconfig) {
        $out->{location} = $cconfig;
    }

    my $json = JSON->new;
    print STDOUT $json->encode($out);
    print STDOUT ")\n" if $cb;
}

sub json_transform_items {
    my($items) = @_;
    my @out;
    foreach my $item (@{$items}) {
	my $subj = $item->{"subj"};
	$subj .= ": " . $item->{"time"} if defined $item->{"time"};
	my $out = {
		   title => $subj,
		   category => $item->{"class"},
		   date => $item->{"dc:date"},
		  };
	$out->{link} = $item->{"link"}
	    if $item->{"class"} =~ /^(parashat|holiday|dafyomi)$/;
	$out->{hebrew} = $item->{"hebrew"}
	    if defined $item->{"hebrew"};
        $out->{yomtov} = \1
            if $item->{"yomtov"};
        $out->{memo} = $item->{"memo"}
            if $item->{"memo"};
        $out->{leyning} = $item->{"leyning"}
            if $item->{"leyning"};
	push(@out, $out);
    }
    \@out;
}

sub upcoming_dow
{
    my($searching_dow) = @_;
    my @today = Date::Calc::Today();
    my $current_dow = Date::Calc::Day_of_Week(@today);

    if ($searching_dow == $current_dow)
    {
	return @today;
    }
    elsif ($searching_dow > $current_dow)
    {
	return Date::Calc::Add_Delta_Days(@today,
					  $searching_dow - $current_dow);
    }
    else
    {
	my @prev = Date::Calc::Add_Delta_Days(@today,
				  $searching_dow - $current_dow);
	return Date::Calc::Add_Delta_Days(@prev,+7);
    }
}

sub get_dow($$$)
{
    my($year,$mon,$mday) = @_;

    my $dow = Date::Calc::Day_of_Week($year,$mon,$mday);
    $dow == 7 ? 0 : $dow;
}

# format the result of HebcalGPL::greg2hebrew
sub format_hebrew_date {
    my($hdate) = @_;
    my $hm = $HebcalGPL::HEB_MONTH_NAME[HebcalGPL::LEAP_YR_HEB($hdate->{"yy"})][$hdate->{"mm"}];
    sprintf("%s of %s, %d", ordinate($hdate->{"dd"}), $hm, $hdate->{"yy"});
}

sub get_default_hebrew_year {
    my($year,$month,$day) = @_;
    my $hebdate = HebcalGPL::greg2hebrew($year,$month,$day);
    my $hyear = $hebdate->{"yy"};
    $hyear++ if ($hebdate->{"mm"} == $HebcalGPL::AV && $hebdate->{"dd"} >= 15)
	|| $hebdate->{"mm"} == $HebcalGPL::ELUL;
    $hyear;
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
	$result = $num2heb{$array[0]} . "\x{5F3}"; # geresh
    }
    else
    {
	$result = '';
	for (my $i = 0; $i < $digits; $i++)
	{
	    $result .= "\x{5F4}" if (($i + 1) == $digits); # gershayim
	    $result .= $num2heb{$array[$i]};
	}
    }

    $result;
}

sub build_hebrew_date($$$)
{
    my($hm,$hd,$hy) = @_;

    my $inprefix = $monthnames_inprefix{$hm}
	|| "\x{5D1}\x{5BC}\x{5B0}" . $monthnames{$hm};

    my $s = hebnum_to_string($hd) . " " . $inprefix;
    if (defined $hy) {
	$s .= " " . hebnum_to_string($hy);
    }
    $s;
}

sub hebrew_strip_nikkud($) {
    my($str) = @_;

    my $result = "";

    foreach my $c (split(//, $str))
    {
	if (ord($c) == 0x05BE) {
	    $result .= $c;
	} elsif (ord($c) > 0x0590 && ord($c) < 0x05D0) {
	    # skip hebrew punctuation range
	} else {
	    $result .= $c;
	}
    }

    return $result;
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

    return $anchor;
}

sub get_holiday_basename {
    my($subj) = @_;

    my $subj_copy = $subj;
    $subj_copy =~ s/ \d{4}$//;               # Rosh Hashana
    $subj_copy =~ s/ \(CH\'\'M\)$//;
    $subj_copy =~ s/ \(Hoshana Raba\)$//;
    if ($subj ne "Rosh Chodesh Adar II") {
        $subj_copy =~ s/ [IV]+$//;
    }

    $subj_copy =~ s/: \d Candles?$//;
    $subj_copy =~ s/: 8th Day$//;
    $subj_copy =~ s/^Erev //;

    $subj_copy;
}

sub get_holiday_anchor($$$)
{
    my($subj,$want_sephardic,$q) = @_;
    my($href) = '';
    my($hebrew) = '';
    my $memo = "";

    if ($subj =~ /^(Parshas\s+|Parashat\s+)(.+)$/)
    {
	my($parashat) = $1;
	my($sedra) = $2;

	# Unicode for "parashat"
	$hebrew = "\x{5E4}\x{5E8}\x{5E9}\x{5EA} ";

	$sedra = $ashk2seph{$sedra} if (defined $ashk2seph{$sedra});

	if (defined $HebcalConst::SEDROT{$sedra})
	{
	    my($anchor) = $sedra;
	    $anchor = lc($anchor);
	    $anchor =~ s/[^\w]//g;

	    $href = 'http://www.hebcal.com'
		if ($q);
	    $href .= "/sedrot/$anchor";

	    $hebrew .= $HebcalConst::SEDROT{$sedra};
	}
	elsif (($sedra =~ /^([^-]+)-(.+)$/) &&
	       (defined $HebcalConst::SEDROT{$1}
		|| defined $HebcalConst::SEDROT{$ashk2seph{$1}}))
	{
	    my($p1,$p2) = ($1,$2);

	    $p1 = $ashk2seph{$p1} if (defined $ashk2seph{$p1});
	    $p2 = $ashk2seph{$p2} if (defined $ashk2seph{$p2});

	    die "aliyah.xml missing $p2!" unless defined $HebcalConst::SEDROT{$p2};

	    my($anchor) = "$p1-$p2";
	    $anchor = lc($anchor);
	    $anchor =~ s/[^\w]//g;

	    $href = 'http://www.hebcal.com'
		if ($q);
	    $href .= "/sedrot/$anchor";

	    $hebrew .= $HebcalConst::SEDROT{$p1};

	    # hypenate hebrew reading
	    # HEBREW PUNCTUATION MAQAF (U+05BE)
	    $hebrew .= "\x{5BE}" . $HebcalConst::SEDROT{$p2};
	}
    }
    elsif ($subj =~ /^(\d+)\w+ day of the Omer$/)
    {
	$hebrew = hebnum_to_string($1) .
	    " \x{5D1}\x{5BC}\x{5B0}\x{5E2}\x{5D5}\x{5B9}\x{5DE}\x{5B6}\x{5E8}";
    }
    elsif ($subj =~ /^(\d+)\w+ of ([^,]+), (\d+)$/)
    {
	my($hm,$hd,$hy) = ($2,$1,$3);

	$hebrew = build_hebrew_date($hm,$hd,$hy);
    }
    elsif ($subj =~ /^Yizkor \(.+\)$/ ||
	   $subj =~ /\'s (Hebrew Anniversary|Hebrew Birthday|Yahrzeit)/)
    {
	# don't generate holiday anchors for yahrzeit calendar
    }
    elsif ($subj =~ /^Daf Yomi:\s+(.+)\s+(\d+)\s*$/)
    {
	my $tractate = $DAFYOMI{$1} || $1;
	my $page = $2;
	$tractate =~ s/ /_/g;
	$href = "http://www.sefaria.org/${tractate}.${page}a";
    }
    else
    {
	my($subj_copy) = $subj;

	$subj_copy = $ashk2seph{$subj_copy}
	    if defined $ashk2seph{$subj_copy};

	# fix Rosh Hashana and Havdalah
	my $subj_suffix;
	if ($subj_copy =~ / (\d{4})$/) {
	    $subj_suffix = " $1";
	    $subj_copy =~ s/ \d{4}$//;
	} elsif ($subj_copy =~ /^Havdalah \((\d+) min\)$/) {
	    $subj_copy = "Havdalah";
	    $subj_suffix = " - $1 \x{05D3}\x{05E7}\x{05D5}\x{05EA}";
    	}

	if (defined $HebcalConst::HOLIDAYS{$subj_copy})
	{
	    $hebrew = $HebcalConst::HOLIDAYS{$subj_copy};
	    if ($subj_suffix) {
		$hebrew .= $subj_suffix;
	    }
	}

	if ($subj ne 'Candle lighting' && $subj !~ /^Havdalah/ &&
	    $subj ne 'No sunset today.')
	{
            $subj_copy = get_holiday_basename($subj_copy);
	    $href = 'http://www.hebcal.com'
		if ($q);
	    $href .= "/holidays/" . make_anchor($subj_copy);
	}

	if (defined $HebcalConst::HOLIDAY_DESCR{$subj_copy}) {
	    $memo = $HebcalConst::HOLIDAY_DESCR{$subj_copy};
	}
    }

    if ($hebrew) {
	$hebrew = hebrew_strip_nikkud($hebrew);
    }

    return (wantarray()) ?
	($href,$hebrew,$memo)
	: $href;
}

sub get_torah_book_id {
    my($book) = @_;
    $book =~ s/\s+.+$//;
    my $bid = 0;
    if ($book =~ /^\d$/) {
	$bid = $book;
    } else {
	$book = lc($book);
	if ($book eq 'genesis') { $bid = 1; }
	elsif ($book eq 'exodus') { $bid = 2; }
	elsif ($book eq 'leviticus') { $bid = 3; }
	elsif ($book eq 'numbers') { $bid = 4; }
	elsif ($book eq 'deuteronomy') { $bid = 5; }
    }
    return $bid;
}

sub get_book_and_verses {
    my($aliyah,$torah) = @_;

    my($c1,$v1) = split(/:/, $aliyah->{'begin'}, 2);
    my($c2,$v2) = split(/:/, $aliyah->{'end'}, 2);
    my($info);
    if ($c1 eq $c2) {
        $info = "$c1:$v1-$v2";
    } else {
        $info = "$c1:$v1-$c2:$v2";
    }

    $torah ||= $aliyah->{"book"}; # special maftirs
    $torah =~ s/\s+.+$//;

    return ($torah, $info);
}

sub get_sefaria_url {
    my($book,$verses) = @_;

    my $sefaria_verses = $verses;
    $sefaria_verses =~ s/:/./g;

    my $sefaria_url = "http://www.sefaria.org/$book.$sefaria_verses?lang=he-en&layout=heLeft&sidebarLang=all";
    return $sefaria_url;
}

sub get_bible_ort_org_url {
    my($book,$chapter,$verse,$parsha_id) = @_;
    my $bid = get_torah_book_id($book);
    return sprintf("http://www.bible.ort.org/books/torahd5.asp?action=displaypage&book=%d&chapter=%d&verse=%d&portion=%d",
		   $bid, $chapter, $verse, $parsha_id);
}


########################################################################
# web page utils
########################################################################

sub script_name($)
{
    my($q) = @_;

    my $script_name;
    if (defined $ENV{"SCRIPT_URL"}) {
	$script_name = $ENV{"SCRIPT_URL"};
    } else {
	$script_name = $q->script_name();
	$script_name =~ s,/\w+\.cgi$,/,;
    }

    $script_name;
}

sub zipcode_open_db
{
    unless ($eval_use_DBI) {
	eval("use DBI");
	$eval_use_DBI = 1;
    }
    my($file) = $_[0] ? $_[0] : $ZIP_SQLITE_FILE;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$file", "", "")
	or die $DBI::errstr;
    $dbh;
}

sub zipcode_close_db($)
{
    my($dbh) = @_;
    $dbh->disconnect();
}

sub zipcode_get_v2_zip($$)
{
    my($dbh,$zipcode) = @_;

    my $sql = qq{
SELECT CityMixedCase,State,Latitude,Longitude,TimeZone,DayLightSaving
FROM ZIPCodes_Primary
WHERE ZipCode = ?
};

    my $sth = $dbh->prepare($sql) or die $dbh->errstr;
    $sth->execute($zipcode) or die $dbh->errstr;

    my($CityMixedCase,$State,$Latitude,$Longitude,$TimeZone,$DayLightSaving) = $sth->fetchrow_array;
    $sth->finish;
    ($CityMixedCase,$State,$Latitude,$Longitude,$TimeZone,$DayLightSaving);
}

sub latlong_to_hebcal {
    my($latitude,$longitude) = @_;

    # remove any prefixed + signs from the strings
    $latitude =~ s/^\+//;
    $longitude =~ s/^\+//;

    # remove any leading zeros
    $latitude =~ s/^(-?)0+/$1/;
    $longitude =~ s/^(-?)0+/$1/;

    $latitude = 0 if $latitude eq "";
    $longitude = 0 if $longitude eq "";

    my $lat_deg = int($latitude);
    my $long_deg = int($longitude) * -1;

    my $lat_min = abs(sprintf("%.0f", ($latitude - int($latitude)) * 60));
    my $long_min = abs(sprintf("%.0f", ($longitude - int($longitude)) * 60));

    ($lat_deg,$lat_min,$long_deg,$long_min);
}


sub zipcode_get_zip_fields($$)
{
    my($dbh,$zipcode) = @_;

    my($CityMixedCase,$State,$Latitude,$Longitude,$TimeZone,$DayLightSaving) =
	zipcode_get_v2_zip($dbh,$zipcode);

    if (! defined $State) {
	warn "zipcode_get_zip_fields: $zipcode Not Found";
	return undef;
    }

    my $tzid = get_usa_tzid($State,$TimeZone,$DayLightSaving);
    my($lat_deg,$lat_min,$long_deg,$long_min) =
	latlong_to_hebcal($Latitude, $Longitude);
    ($CityMixedCase,$State,$tzid,
     $Latitude,$Longitude,$lat_deg,$lat_min,$long_deg,$long_min);
}

sub woe_city
{
    my($id) = @_;
    return $HebcalConst::CITIES_NEW{$id}->[1];
}

sub woe_country_code
{
    my($id) = @_;
    return $HebcalConst::CITIES_NEW{$id}->[0];
}

sub woe_country
{
    my($id) = @_;
    my $country_name = $HebcalConst::COUNTRIES{woe_country_code($id)}->[0];
    $country_name =~ s/,\s+.+$//;
    $country_name;
}

sub woe_city_descr {
    my($id) = @_;
    my $country = woe_country($id);
    $country = "USA" if $country eq "United States of America";
    $country = "UK" if $country eq "United Kingdom";
    my $city_descr = woe_city($id) . ", $country";
    return $city_descr;
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
	} elsif ($q->param('geo') eq 'city') {
	    $retval .= '&city=' . URI::Escape::uri_escape_utf8($q->param('city'));
	} elsif ($q->param('geo') eq 'geoname') {
	    $retval .= '&geonameid=' . $q->param('geonameid');
	} elsif ($q->param('geo') eq 'pos') {
	    $retval .= '&lodeg=' . $q->param('lodeg');
	    $retval .= '&lomin=' . $q->param('lomin');
	    $retval .= '&lodir=' . $q->param('lodir');
	    $retval .= '&ladeg=' . $q->param('ladeg');
	    $retval .= '&lamin=' . $q->param('lamin');
	    $retval .= '&ladir=' . $q->param('ladir');
	    $retval .= '&tzid=' . URI::Escape::uri_escape_utf8($q->param('tzid'))
	        if defined $q->param('tzid') && $q->param('tzid') ne '';
	}
        foreach (qw(m b geo)) {
            $retval .= "&$_=" . $q->param($_)
                if defined $q->param($_) && $q->param($_) ne '';
        }
    }

    # boolean options
    foreach (@opts, qw(maj nx ss mf min mod)) {
        if (defined $q->param($_)) {
            $retval .= "&$_=" . $q->param($_);
        } elsif (!defined $q->param($_) || $q->param($_) eq 'off') {
            $retval .= "&$_=off";
        }
    }

    $retval .= "&lg=" . $q->param('lg') if defined $q->param('lg');

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
	    }
	} elsif (defined $c->param('geonameid') && $c->param('geonameid') =~ /^\d+$/ &&
	    (! defined $q->param('geo') || $q->param('geo') eq 'geoname')) {
	    $q->param('geo','geoname');
	    $q->param('c','on');
	    if (! defined $q->param('geonameid') || $q->param('geonameid') =~ /^\s*$/) {
		$q->param('geonameid',$c->param('geonameid'));
	    }
	} elsif (defined $c->param('city') && $c->param('city') ne '' &&
		 (! defined $q->param('geo') || $q->param('geo') eq 'city')) {
	    $q->param('city',$c->param('city'))
		unless $q->param('city');
	    $q->param('geo','city');
	    $q->param('c','on');
	    if (defined $CITY_COUNTRY{$q->param('city')} &&
		$CITY_COUNTRY{$q->param('city')} eq 'IL')
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
	    foreach (qw(lodeg lomin ladeg lamin lodir ladir)) {
		$q->param($_, $c->param($_))
		    unless $q->param($_);
	    }
	    $q->param('geo','pos');
	    $q->param('c','on');
	    $q->param('tzid',$c->param('tzid'))
		if (defined $c->param('tzid') && ! defined $q->param('tzid'));
	}
    }

    $q->param('m',$c->param('m'))
	if (defined $c->param('m') && ! defined $q->param('m'));

    foreach (@opts)
    {
	next if $_ eq 'c';
	$q->param($_,$c->param($_))
	    if (! defined $q->param($_) && defined $c->param($_));
    }

    if (defined $c->param("nh")) {
        foreach my $opt (qw(maj min mod)) {
            $c->param($opt, $c->param("nh"));
        }
        $c->delete("nh");
    }

    foreach (qw(maj nx ss mf lg min mod)) {
	$q->param($_, $c->param($_))
	    if (! defined $q->param($_) && defined $c->param($_));
    }

    $c;
}

########################################################################
# EXPORT
########################################################################

sub self_url
{
    my($q,$override,$next_sep) = @_;

    my $url = script_name($q);
    my $sep = "?";
    $next_sep ||= ";";

    foreach my $key ($q->param())
    {
	# delete "utm_source" params unless explicitly specified
	next if $key eq "utm_source" && !exists $override->{"utm_source"};
	# ignore undef entries in the override hash
	next if exists $override->{$key} && !defined $override->{$key};
	my($val) = defined $override->{$key} ?
	    $override->{$key} : $q->param($key);
	$url .= "$sep$key=" . URI::Escape::uri_escape_utf8($val);
	$sep = $next_sep;
    }

    foreach my $key (keys %{$override})
    {
	# ignore undef entries in the override hash
	next unless defined $override->{$key};
	unless (defined $q->param($key))
	{
	    $url .= "$sep$key=" . URI::Escape::uri_escape_utf8($override->{$key});
	    $sep = $next_sep;
	}
    }

    $url;
}

sub get_geo_args {
    my($q,$separator) = @_;
    $separator = '&' unless defined $separator;
    if (defined $q->param('zip') && $q->param('zip') =~ /^\d+$/) {
	return 'zip=' . $q->param('zip');
    } elsif (defined $q->param('city') && $q->param('city') ne '') {
	return 'city=' . URI::Escape::uri_escape_utf8($q->param('city'));
    } elsif (defined $q->param('geonameid') && $q->param('geonameid') =~ /^\d+$/) {
        my $retval = 'geonameid=' . $q->param('geonameid');
        if ($q->param("city-typeahead")) {
            $retval .= join('', $separator, "city-typeahead=",
                URI::Escape::uri_escape_utf8($q->param("city-typeahead")));
        }
        return $retval;
    } elsif (defined $q->param('geo') && $q->param('geo') eq 'pos') {
	my $sep = '';
	my $retval = '';
	foreach (qw(city-typeahead lodeg lomin ladeg lamin lodir ladir tzid)) {
	    $retval .= "$sep$_=" . URI::Escape::uri_escape_utf8($q->param($_));
	    $sep = $separator;
	}
	return $retval;
    }
    '';
}

sub download_href
{
    my($q,$filename,$ext) = @_;

    my $cgi;
    my $script_name = $q->script_name();
    if ($script_name =~ /(\w+\.cgi)$/)
    {
	$cgi = $1;
	$script_name =~ s,/\w+\.cgi$,/,;
    }

    my $href = "http://download.hebcal.com" . $script_name;
    $href .= $cgi if $cgi;
    $href .= "/$filename.$ext?dl=1";
    foreach my $key ($q->param()) {
	my $val = defined $q->param($key) ? $q->param($key) : "";
	$href .= ";$key=" . URI::Escape::uri_escape_utf8($val);
    }

    $href;
}

# Zip-Codes.com TimeZone IDs
#
# Code 	Description
#  4	Atlantic (GMT -04:00)
#  5	Eastern (GMT -05:00)
#  6	Central (GMT -06:00)
#  7	Mountain (GMT -07:00)
#  8	Pacific (GMT -08:00)
#  9	Alaska (GMT -09:00)
# 10	Hawaii-Aleutian Islands (GMT -10:00)
# 11	American Samoa (GMT -11:00)
# 13	Marshall Islands (GMT +12:00)
# 14	Guam (GMT +10:00)
# 15	Palau (GMT +9:00)
my %ZIPCODES_TZ_MAP = (
'0' => 'UTC',
'4' => 'America/Puerto_Rico',
'5' => 'America/New_York',
'6' => 'America/Chicago',
'7' => 'America/Denver',
'8' => 'America/Los_Angeles',
'9' => 'America/Anchorage',
'10' => 'Pacific/Honolulu',
'11' => 'Pacific/Pago_Pago',
'13' => 'Pacific/Funafuti',
'14' => 'Pacific/Guam',
'15' => 'Pacific/Palau',
);

sub process_args_common_jerusalem {
    my($q,$cconfig) = @_;
    # special case for candles 40 minutes before sunset...
    my $city = "IL-Jerusalem";
    $q->param("city", $city);
    $q->param("geo","city");

    my($latitude,$longitude) = @{$CITY_LATLONG{$city}};
    my $cmd = "./hebcal -C 'Jerusalem'";
    my $city_descr = "Jerusalem, Israel";
    $q->param("i", "on");
    foreach (qw(zip lodeg lomin ladeg lamin lodir ladir tz dst tzid geonameid city-typeahead)) {
	$q->delete($_);
    }
    if (defined $cconfig) {
	$cconfig->{"latitude"} = $latitude;
	$cconfig->{"longitude"} = $longitude;
	$cconfig->{"title"} = $city_descr;
	$cconfig->{"city"} = "Jerusalem";
	$cconfig->{"tzid"} = "Asia/Jerusalem";
	$cconfig->{"geo"} = "city";
    }
    (1,$cmd,$latitude,$longitude,$city_descr);
}

sub process_args_common_zip {
    my($q,$cconfig) = @_;

    if ($q->param('zip') !~ /^\d{5}$/) {
	my $message = "Sorry, <strong>" . $q->param('zip')
	    . "</strong> does not appear to be a 5-digit zip code.";
	return (0,$message,undef);
    }

    my $DB = zipcode_open_db();
    my($city,$state,$tzid,$latitude,$longitude,$lat_deg,$lat_min,$long_deg,$long_min) =
	zipcode_get_zip_fields($DB, $q->param("zip"));
    zipcode_close_db($DB);
    undef($DB);

    unless (defined $state) {
	my $message = "Sorry, can't find <strong>" . $q->param('zip') .
	    "</strong> in the zip code database.";
	my $help = "<ul><li>Please try a nearby zip code</li></ul>";
	return (0,$message,$help);
    }

    my $cmd = "./hebcal -L $long_deg,$long_min -l $lat_deg,$lat_min -z '$tzid'";
    my $city_descr = "$city, $state " . $q->param('zip');

    $q->param("geo", "zip");
    foreach (qw(city lodeg lomin ladeg lamin lodir ladir tz dst tzid geonameid city-typeahead)) {
	$q->delete($_);
    }
    if (defined $cconfig) {
	$cconfig->{"latitude"} = $latitude;
	$cconfig->{"longitude"} = $longitude;
	$cconfig->{"title"} = $city_descr;
	$cconfig->{"city"} = $city;
	$cconfig->{"state"} = $state;
	$cconfig->{"zip"} = $q->param("zip");
	$cconfig->{"tzid"} = $tzid;
	$cconfig->{"geo"} = "zip";
    }
    (1,$cmd,$latitude,$longitude,$city_descr);
}

sub geoname_lookup {
    my($geonameid) = @_;
    my $dbh = zipcode_open_db($GEONAME_SQLITE_FILE);
    $dbh->{sqlite_unicode} = 1;
    my $sql = qq{
SELECT g.name, g.asciiname, c.country, a.name, g.latitude, g.longitude, g.timezone
FROM geoname g
LEFT JOIN country c on g.country = c.iso
LEFT JOIN admin1 a on g.country||'.'||g.admin1 = a.key
WHERE g.geonameid = ?
};
    my $sth = $dbh->prepare($sql) or die $dbh->errstr;
    $sth->execute($geonameid) or die $dbh->errstr;
    my($name,$asciiname,$country,$admin1,$latitude,$longitude,$tzid) = $sth->fetchrow_array;
    $sth->finish;
    zipcode_close_db($dbh);
    undef($dbh);
    return ($name,$asciiname,$country,$admin1,$latitude,$longitude,$tzid);
}

sub geoname_city_descr {
    my($name,$admin1,$country) = @_;
    $country = "USA" if $country eq "United States";
    $country = "UK" if $country eq "United Kingdom";
    my $city_descr = $name;
    $city_descr .= ", $admin1" if $admin1 && index($admin1, $name) != 0;
    $city_descr .= ", $country" if $country;
    return $city_descr;
}

sub process_args_common_geoname {
    my($q,$cconfig) = @_;
    my($name,$asciiname,$country,$admin1,$latitude,$longitude,$tzid) =
      geoname_lookup($q->param('geonameid'));

    unless (defined $name) {
        my $message = "Sorry, can't find <strong>" . $q->param('geonameid') .
            "</strong> in the location database.";
        my $help = "<ul><li>Please search for a different location</li></ul>";
        return (0, $message, $help);
    }

    my($lat_deg,$lat_min,$long_deg,$long_min) =
        latlong_to_hebcal($latitude, $longitude);
    my $cmd = "./hebcal -L $long_deg,$long_min -l $lat_deg,$lat_min -z '$tzid'";
    my $city_descr = geoname_city_descr($name,$admin1,$country);
    if ($country eq "Israel") {
	$q->param('i','on');
        $q->param('b','40')
            if ! defined $q->param('b') && $admin1 eq "Jerusalem District";
    }
    $q->param("geo", "geoname");
    foreach (qw(zip city lodeg lomin ladeg lamin lodir ladir tz dst tzid city-typeahead)) {
	$q->delete($_);
    }
    if (defined $cconfig) {
	$cconfig->{"latitude"} = $latitude;
	$cconfig->{"longitude"} = $longitude;
	$cconfig->{"title"} = $city_descr;
	$cconfig->{"city"} = $name;
	$cconfig->{"tzid"} = $tzid;
	$cconfig->{"geo"} = "geoname";
        $cconfig->{"geonameid"} = int($q->param('geonameid'));
    }
    (1,$cmd,$latitude,$longitude,$city_descr);
}

sub legacy_tz_dst_to_tzid {
    my($tz,$dst) = @_;
    if ($tz eq "0" && $dst eq "none") {
        return "UTC";
    } elsif ($tz eq "2" && $dst eq "israel") {
        return "Asia/Jerusalem";
    } elsif ($tz eq "0" && $dst eq "eu") {
        return "Europe/London";
    } elsif ($tz eq "1" && $dst eq "eu") {
        return "Europe/Paris";
    } elsif ($tz eq "2" && $dst eq "eu") {
        return "Europe/Athens";
    } elsif ($dst eq "usa" && defined $ZIPCODES_TZ_MAP{int($tz * -1)}) {
        return $ZIPCODES_TZ_MAP{int($tz * -1)};
    }
    return undef;
}

sub process_args_common_geopos {
    my($q,$cconfig) = @_;

    my %maxval = ("ladeg" =>  90, "lamin" => 60,
		  "lodeg" => 180, "lomin" => 60);
    foreach my $key (qw(lodeg lomin ladeg lamin)) {
	my $value = $q->param($key);
	my $message;
	if ($value !~ /^\d+$/) {
	    $message = "Sorry, all latitude/longitude arguments must be numeric.";
	} elsif ($value > $maxval{$key}) {
	    my $keyname = (substr($key, 1, 1) eq "a") ? "latitude" : "longitude";
	    $keyname .= (substr($key, 2, 1) eq "d") ? " degrees" : " minutes";
	    $message = "Sorry, $keyname <strong>$value</strong> out of valid range 0-$maxval{$key}";
	}
	return (0, $message, undef) if $message;
    }

    my($long_deg,$long_min,$lat_deg,$lat_min) =
	($q->param("lodeg"),$q->param("lomin"),
	 $q->param("ladeg"),$q->param("lamin"));

    $q->param("lodir","w") unless ($q->param("lodir") eq "e");
    $q->param("ladir","n") unless ($q->param("ladir") eq "s");

    $q->param("geo","pos");

    # Geographic Position
    my $city_descr = sprintf("%d\x{b0}%d\x{2032}%s, %d\x{b0}%d\x{2032}%s",
			     $lat_deg, $lat_min, uc($q->param("ladir")),
			     $long_deg, $long_min, uc($q->param("lodir")));

    my $latitude = $lat_deg + ($lat_min / 60.0);
    my $longitude = $long_deg + ($long_min / 60.0);
    $latitude *= -1 if $q->param("ladir") eq "s";
    $longitude *= -1 if $q->param("lodir") eq "w";

    # don't multiply minutes by -1 since hebcal does it internally
    $long_deg *= -1  if ($q->param("lodir") eq "e");
    $lat_deg  *= -1  if ($q->param("ladir") eq "s");

    my $cmd = "./hebcal -L $long_deg,$long_min -l $lat_deg,$lat_min";

    # special-case common old-style URLs
    if (! defined $q->param("tzid")
	&& defined $q->param("tz")
	&& defined $q->param("dst")) {
        my $tzid = legacy_tz_dst_to_tzid($q->param("tz"), $q->param("dst"));
        $q->param("tzid", $tzid) if $tzid;
    }

    if (! defined $q->param("tzid")) {
	return (0, "Please select a Time zone", undef);
    }

    if (!is_timezone_valid($q->param("tzid"))) {
        return (0, "Sorry, can't find <strong>" . $q->param("tzid")
            . "</strong> in our Time zone database", undef);
    }

    my $tzid = $q->param("tzid");
    $cmd .= " -z '$tzid'";
    $city_descr .= ", $tzid";

    foreach (qw(city zip tz dst geonameid)) {
	$q->delete($_);
    }
    if (defined $cconfig) {
	$cconfig->{"latitude"} = $latitude;
	$cconfig->{"longitude"} = $longitude;
	$cconfig->{"lat_deg"} = $lat_deg;
	$cconfig->{"lat_min"} = $lat_min;
	$cconfig->{"long_deg"} = $long_deg;
	$cconfig->{"long_min"} = $long_min;
	if (defined $q->param("city-typeahead") && $q->param("city-typeahead") !~ /^\s*$/) {
	    $cconfig->{"title_pos"} = $city_descr;
	    my $city_typeahead = $q->param("city-typeahead");
	    $city_typeahead =~ s/^\s+//; # trim leading and trailing whitespace
	    $city_typeahead =~ s/\s+$//;
	    $city_descr = $city_typeahead; # save full string for return value
	    $city_typeahead =~ s/,.+//;
	    $cconfig->{"city"} = $city_typeahead; # short name for title tag
	}
	$cconfig->{"title"} = $city_descr;
	$cconfig->{"tzid"} = $tzid;
	$cconfig->{"geo"} = "pos";
    }
    (1,$cmd,$latitude,$longitude,$city_descr);
}

sub process_args_common_city {
    my($q,$cconfig) = @_;
    my $city = validate_city($q->param("city"));
    if (! defined $city) {
	if (defined $q->param("cfg") && $q->param("cfg") =~ /^(json|xml|r|e|e2)$/) {
	    my $city2 = $q->param("city") || "";
	    return (0, "Unknown city '$city2'", undef);
	} else {
	    $city = "US-New York-NY";
	}
    }

    $q->param("city", $city);
    $q->param("geo","city");

    my($latitude,$longitude) = @{$CITY_LATLONG{$city}};
    my($lat_deg,$lat_min,$long_deg,$long_min) =
	latlong_to_hebcal($latitude, $longitude);
    my $tzid = $CITY_TZID{$city};

    my $cmd = "./hebcal -L $long_deg,$long_min -l $lat_deg,$lat_min -z '$tzid'";

    my $city_descr = woe_city_descr($city);

    if ($CITY_COUNTRY{$city} eq 'IL') {
	$q->param('i','on');
    }
    foreach (qw(zip lodeg lomin ladeg lamin lodir ladir tz dst tzid city-typeahead geonameid)) {
	$q->delete($_);
    }
    if (defined $cconfig) {
	$cconfig->{"latitude"} = $latitude;
	$cconfig->{"longitude"} = $longitude;
	$cconfig->{"title"} = $city_descr;
	$cconfig->{"city"} = woe_city($city);
	$cconfig->{"tzid"} = $tzid;
	$cconfig->{"geo"} = "city";
    }
    (1,$cmd,$latitude,$longitude,$city_descr);
}

sub process_args_common_none {
    my($q,$cconfig) = @_;
    $q->param("geo","none");
    $q->param("c","off");
    foreach (qw(m b zip city lodeg lomin ladeg lamin lodir ladir tz dst tzid city-typeahead geonameid)) {
	$q->delete($_);
    }
    if (defined $cconfig) {
	$cconfig->{"geo"} = "none";
    }
    my $cmd = "./hebcal";
    (1,$cmd,undef,undef,undef);
}

sub process_args_common {
    my($q,$handle_cookie,$default_to_nyc,$cconfig) = @_;

    if ($handle_cookie) {
	# default setttings needed for cookie
	foreach (qw(c maj nx)) {
	    $q->param($_, "on");
	}

	my $cookies = get_cookies($q);
	if (defined $cookies->{'C'}) {
	    process_cookie($q,$cookies->{'C'});
	}
    }

    my @status;
    if (defined $q->param("city") &&
	($q->param("city") eq "Jerusalem" || $q->param("city") eq "IL-Jerusalem")) {
	@status = process_args_common_jerusalem($q, $cconfig);
    } elsif (defined $q->param('zip') && $q->param('zip') ne '') {
	@status = process_args_common_zip($q, $cconfig);
    } elsif (defined $q->param('geonameid') && $q->param('geonameid') =~ /^\d+$/) {
	if ($q->param('geonameid') == 281184) {
	    @status = process_args_common_jerusalem($q, $cconfig);
	} else {
	    @status = process_args_common_geoname($q, $cconfig);
	}
    } elsif (defined $q->param("lodeg") && defined $q->param("lomin") &&
	     defined $q->param("ladeg") && defined $q->param("lamin") &&
	     defined $q->param("lodir") && defined $q->param("ladir") &&
	     $q->param("lodeg") ne '' && $q->param("lomin") ne '' &&
	     $q->param("ladeg") ne '' && $q->param("lamin") ne '') {
	@status = process_args_common_geopos($q, $cconfig);
    } elsif ($default_to_nyc ||
	     (defined $q->param("city") && $q->param("city") ne "")) {
	@status = process_args_common_city($q, $cconfig);
    } else {
	@status = process_args_common_none($q, $cconfig);
    }

    return @status unless $status[0];
    my($cmd,$latitude,$longitude,$city_descr) = @status[1..4];

    # candle-lighting minutes before sundown (-b)
    # and Havdalah mins after sundown (-m)
    foreach (qw(b m)) {
        $cmd .= join('', ' -', $_, ' ', $q->param($_))
            if defined $q->param($_) && $q->param($_) =~ /^\d+$/;
    }

    foreach (qw(a i)) {
	$cmd .= ' -' . $_
	    if defined $q->param($_) && $q->param($_) =~ /^on|1$/;
    }

    return (1,$cmd,$latitude,$longitude,$city_descr);
}


sub validate_city {
    my($city) = @_;
    unless (defined $city) {
	return undef;
    }
    if (defined($CITIES_OLD{$city})) {
	return $CITIES_OLD{$city};
    }
    if (defined($CITY_TZID{$city})) {
	return $city;
    }
    return undef;
}


sub get_usa_tzid {
    my($state,$tz,$dst) = @_;
    if (defined $state && $state eq 'AK' && $tz == 10) {
	return 'America/Adak';
    } elsif (defined $state && $state eq 'AZ' && $tz == 7) {
	if ($dst eq 'Y') {
	    return 'America/Denver';
	} else {
	    return 'America/Phoenix';
	}
    } else {
	return $ZIPCODES_TZ_MAP{$tz};
    }
}


sub get_munged_qs
{
    my($args) = @_;

    my $qs;
    if ($args) {
	$qs = $args;
    } elsif ($ENV{"REQUEST_URI"} && $ENV{"REQUEST_URI"} =~ /\?(.+)$/) {
	$qs = $1;
    } else {
	$qs = "bogus";
    }

    # first translate all ampersands and semicolons into commas
    $qs =~ s/&amp;/,/g;
    $qs =~ s/&/,/g;
    $qs =~ s/;/,/g;

    # now delete selected parameters
    $qs =~ s/,?(tag|utm_source|utm_campaign|set|vis|subscribe|dl)=[^,]+//g;
    $qs =~ s/,?\.(from|cgifields|s)=[^,]+//g;
    $qs =~ s/^,+//g;
    $qs =~ s/\./_/g;
    $qs =~ s/\//-/g;
    $qs =~ s/\%20/+/g;
    $qs =~ s/[\<\>\s\"\'\`\?\*\$\|\[\]\{\}\\\~]//g; # unsafe chars

    return $qs;
}

sub get_vcalendar_cache_fn
{
    my($args) = @_;

    my $qs = get_munged_qs($args);
    my $digest = Digest::MD5::md5_hex($qs);
    my $dir = substr($digest, 0, 2);
    my $fn = substr($digest, 2) . ".ics";

    return "/export/$dir/$fn";
}


sub torah_calendar_memo_inner {
    my($dbh,$sth,$gy,$gm,$gd) = @_;
    my $date_sql = sprintf("%04d-%02d-%02d", $gy, $gm, $gd);
    my $rv = $sth->execute($date_sql) or die $dbh->errstr;
    my $result = {};
    while(my($aliyah_num,$aliyah_reading) = $sth->fetchrow_array) {
        $result->{$aliyah_num} = $aliyah_reading;
    }
    $sth->finish;
    return $result;
}

sub torah_calendar_memo {
    my($dbh,$sth,$gy,$gm,$gd) = @_;
    my $leyning = torah_calendar_memo_inner($dbh,$sth,$gy,$gm,$gd);
    my $memo;
    if ($leyning && $leyning->{'T'}) {
        $memo = "Torah: " . $leyning->{'T'};
        if ($leyning->{'7'} && $leyning->{'7'} =~ / \| /) {
            $memo .= "\\n7th aliyah: " . $leyning->{'7'};
        }
        if ($leyning->{'8'}) {
            $memo .= "\\n8th aliyah: " . $leyning->{'8'};
        }
        if ($leyning->{'M'} && $leyning->{'M'} =~ / \| /) {
            $memo .= "\\nMaftir: " . $leyning->{'M'};
        }
        if ($leyning->{'H'}) {
            $memo .= "\\nHaftarah: " . $leyning->{'H'};
        }
    }
    return $memo;
}

sub translate_subject
{
    my($q,$subj,$hebrew) = @_;

    my $lang = $q->param("lg") || "s";
    if ($lang eq "s" || $lang eq "a" || !$hebrew) {
	return $subj;
    } elsif ($lang eq "h") {
	return $hebrew;
    } elsif ($lang eq "ah" || $lang eq "sh") {
	return "$subj / $hebrew";
    } else {
	die "unknown lang \"$lang\" for $subj";
    }
}


########################################################################
# for managing email shabbat list
########################################################################

sub shabbat_return_path {
    my($to) = @_;
    $to =~ s/\@/=/g;
    return join('', 'shabbat-return+', $to, '@hebcal.com');
}

sub sendmail_v2
{
    my($return_path,$headers,$body,$verbose) = @_;

    eval("use MIME::Lite");

    if (!$HOSTNAME) {
        $HOSTNAME = `/bin/hostname -f`;
        chomp($HOSTNAME);
    }

    $headers->{"X-Mailer"} ||= "Hebcal.pm mail v5.3";
    $headers->{"Message-ID"} ||= "<HEBCAL." . time() . ".$$\@$HOSTNAME>";

    my $msg = MIME::Lite->new(Type => $headers->{'Content-Type'});
    while (my($key,$val) = each %{$headers}) {
        next if $key eq 'Content-Type';
        while (chomp($val)) {}
        $msg->add($key => $val);
    }

    $msg->replace("Return-Path" => $return_path);

    eval { $msg->send("smtp", "localhost", Timeout => 20); };
    if ($@) {
        warn $@ if $verbose;
        return 0;
    } else {
        return 1;
    }

    1;
}

########################################################################
# from Lingua::EN::Numbers::Ordinate
########################################################################

sub ordsuf ($) {
  return 'th' if not(defined($_[0])) or not( 0 + $_[0] );
   # 'th' for undef, 0, or anything non-number.
  my $n = abs($_[0]);  # Throw away the sign.
  return 'th' unless $n == int($n); # Best possible, I guess.
  $n %= 100;
  return 'th' if $n == 11 or $n == 12 or $n == 13;
  $n %= 10;
  return 'st' if $n == 1;
  return 'nd' if $n == 2;
  return 'rd' if $n == 3;
  return 'th';
}

sub ordinate ($) {
  my $i = $_[0] || 0;
  return $i . ordsuf($i);
}

# avoid warnings
if ($^W && 0)
{
    my $unused;
    $unused = $DBI::errstr;
}

1;
