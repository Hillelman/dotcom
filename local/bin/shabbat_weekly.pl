#!/usr/local/bin/perl -w

# $Source: /Users/mradwin/hebcal-copy/local/bin/RCS/shabbat_weekly.pl,v $
# $Id$

use lib "/home/mradwin/local/share/perl";
use lib "/home/mradwin/local/share/perl/site_perl";

use strict;
use Hebcal ();
use POSIX qw(strftime);
use MIME::Base64 ();
use Time::Local ();
use DBI ();

die "usage: $0 {-all | address ...}\n" unless @ARGV;

my $site = 'hebcal.com';

my $now = time;
my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
    localtime($now);
$year += 1900;

my $friday = Time::Local::timelocal(0,0,0,$mday,$mon,$year,$wday,$yday,$isdst);
my $saturday = $now + ((6 - $wday) * 60 * 60 * 24);
my $sat_year = (localtime($saturday))[5] + 1900;
my $subject = strftime("[shabbat] %b %d",
		       localtime($now + ((5 - $wday) * 60 * 60 * 24)));

my $ZIPS = Hebcal::zipcode_open_db('/home/mradwin/web/hebcal.com/hebcal/zips99.db');

my(%SUBS) = load_subs();
if (! keys(%SUBS) && ($ARGV[0] ne '-all')) {
    die "$ARGV[0]: not found.\n";
}

# walk through subs to make sure there are no errors first
while (my($to,$cfg) = each(%SUBS))
{
    next if $cfg =~ /^action=/;
    next if $cfg =~ /^type=alt/;
    parse_config($cfg);
}

while (my($to,$cfg) = each(%SUBS))
{
    next if $cfg =~ /^action=/;
    next if $cfg =~ /^type=alt/;
    my($cmd,$loc,$args) = parse_config($cfg);
    my(@events) = Hebcal::invoke_hebcal($cmd,'',undef);

    my $encoded = MIME::Base64::encode_base64($to);
    chomp($encoded);
    my $unsub_url = "http://www.$site/email/?" .
	"e=" . my_url_escape($encoded);

    my($body) = gen_body(\@events) . qq{
$loc

Shabbat Shalom,
$site

To modify your subscription, visit:
$unsub_url

To unsubscribe from this list, send an email to:
shabbat-unsubscribe\@$site
};

    my $email_mangle = $to;
    $email_mangle =~ s/\@/=/g;
    my $return_path = sprintf('shabbat-return-%s@%s', $email_mangle, $site);

    my $lighting = get_friday_candles(\@events);

    my %headers =
        (
         'From' => "Hebcal <shabbat-owner\@$site>",
         'To' => $to,
         'MIME-Version' => '1.0',
         'Content-Type' => 'text/plain',
         'Subject' => "$subject Candles $lighting",
	 'List-Unsubscribe' => "<$unsub_url>",
	 'Precedence' => 'bulk',
         );

    # try 3 times to avoid intermittent failures
    my($status) = 0;
    for (my $i = 0; $status == 0 && $i < 3; $i++)
    {
	$status = Hebcal::sendmail_v2($return_path,\%headers,$body);
	sleep(2);
    }

#    warn "$0: unable to email $to\n" if ($status == 0);
}

Hebcal::zipcode_close_db($ZIPS);
undef($ZIPS);

exit(0);

sub my_url_escape
{
    my($str) = @_;

    $str =~ s/([^\w\$. -])/sprintf("%%%02X", ord($1))/eg;
    $str =~ s/ /+/g;

    $str;
}

sub get_friday_candles
{
    my($events) = @_;
    my($numEntries) = scalar(@{$events});
    my($i);
    for ($i = 0; $i < $numEntries; $i++)
    {
	my($time) = Time::Local::timelocal(1,0,0,
		       $events->[$i]->[$Hebcal::EVT_IDX_MDAY],
		       $events->[$i]->[$Hebcal::EVT_IDX_MON],
		       $events->[$i]->[$Hebcal::EVT_IDX_YEAR] - 1900,
		       '','','');
	next if $time < $friday || $time > $saturday;

	my($subj) = $events->[$i]->[$Hebcal::EVT_IDX_SUBJ];
	if ($subj eq 'Candle lighting')
	{
	    my($min) = $events->[$i]->[$Hebcal::EVT_IDX_MIN];
	    my($hour) = $events->[$i]->[$Hebcal::EVT_IDX_HOUR];
	    $hour -= 12 if $hour > 12;

	    return sprintf("%d:%02dpm", $hour, $min);
	}
    }

    return '';
}

sub gen_body
{
    my($events) = @_;

    my $body = '';

    my($numEntries) = scalar(@{$events});
    my($i);
    for ($i = 0; $i < $numEntries; $i++)
    {
	# holiday is at 12:00:01 am
	my($time) = Time::Local::timelocal(1,0,0,
		       $events->[$i]->[$Hebcal::EVT_IDX_MDAY],
		       $events->[$i]->[$Hebcal::EVT_IDX_MON],
		       $events->[$i]->[$Hebcal::EVT_IDX_YEAR] - 1900,
		       '','','');
	next if $time < $friday || $time > $saturday;

	my($subj) = $events->[$i]->[$Hebcal::EVT_IDX_SUBJ];
	my($year) = $events->[$i]->[$Hebcal::EVT_IDX_YEAR];
	my($mon) = $events->[$i]->[$Hebcal::EVT_IDX_MON] + 1;
	my($mday) = $events->[$i]->[$Hebcal::EVT_IDX_MDAY];

	my($min) = $events->[$i]->[$Hebcal::EVT_IDX_MIN];
	my($hour) = $events->[$i]->[$Hebcal::EVT_IDX_HOUR];
	$hour -= 12 if $hour > 12;

	my $strtime = strftime("%A, %d %B %Y", localtime($time));

	if ($subj eq 'Candle lighting' || $subj =~ /Havdalah/)
	{
	    $body .= sprintf("%s for %s is at %d:%02dpm\n",
			     $subj, $strtime, $hour, $min);
	}
	elsif ($subj eq 'No sunset today.')
	{
	    $body .= "No sunset on $strtime\n";
	}
	elsif ($subj =~ /^(Parshas|Parashat)\s+/)
	{
	    $body .= "This week's Torah portion is $subj\n";
	    $body .= "  http://www.$site" .
	      Hebcal::get_holiday_anchor($subj,undef,undef) . "\n";
	}
	else
	{
	    $body .= "Holiday: $subj on $strtime\n";
	}
    }

    $body;
}

sub load_subs
{
    my(%subs);

    my $dsn = 'DBI:mysql:database=hebcal1;host=mysql.hebcal.com';
    my $dbh = DBI->connect($dsn, 'mradwin_hebcal', 'xxxxxxxx');

    my $all_sql = '';
    if ($ARGV[0] ne '-all') {
	$all_sql = "AND email_address = '$ARGV[0]'";
    }

    my $sql = <<EOD
SELECT email_address,
       email_id,
       email_candles_zipcode,
       email_candles_city,
       email_candles_havdalah
FROM hebcal1.hebcal_shabbat_email
WHERE hebcal1.hebcal_shabbat_email.email_status = 'active'
$all_sql
EOD
;

    my $sth = $dbh->prepare($sql);
    my $rv = $sth->execute
	or die "can't execute the query: " . $sth->errstr;
    while (my($email,$id,$zip,$city,$havdalah) = $sth->fetchrow_array) {
	my $cfg = "id=$id;m=$havdalah";
	if ($zip) {
	    $cfg .= ";zip=$zip";
	} elsif ($city) {
	    $cfg .= ";city=$city";
	}
	$subs{$email} = $cfg;
    }

    $dbh->disconnect;
    %subs;
}

sub parse_config
{
    my($config) = @_;

    my($cmd) = '/home/mradwin/web/hebcal.com/bin/hebcal';

    my %args;
    foreach my $kv (split(/;/, $config)) {
	my($key,$val) = split(/=/, $kv, 2);
	$args{$key} = $val;
    }

    my $city_descr;
    if (defined $args{'zip'}) {
	my($zipinfo) = $ZIPS->{$args{'zip'}};
	die "unknown zipcode [$config]" unless defined $zipinfo;
    
	my($long_deg,$long_min,$lat_deg,$lat_min,$tz,$dst,$city,$state) =
	    Hebcal::zipcode_fields($zipinfo);

	$city_descr = "These times are for:";
	$city_descr .= "\n  $city, $state " . $args{'zip'};
	$city_descr .= "\n  " . $Hebcal::tz_names{$tz};

	if (defined $tz && $tz ne '?') {
	    $cmd .= " -z $tz";
	}

	if ($dst == 1) {
	    $cmd .= " -Z usa";
	} elsif ($dst == 0) {
	    $cmd .= " -Z none";
	}

	$cmd .= " -L $long_deg,$long_min -l $lat_deg,$lat_min";
    } elsif (defined $args{'city'}) {
	$city_descr = $args{'city'};
	$city_descr =~ s/\+/ /g;
	$cmd .= " -C '" . $city_descr . "'";
	$cmd .= " -i"
	    if ($Hebcal::city_dst{$city_descr} eq 'israel');
	$city_descr = "These times are for $city_descr.";
    } else {
	die "no geographic key in [$config]";
    }

    $cmd .= " -m " . $args{'m'}
	if (defined $args{'m'} && $args{'m'} =~ /^\d+$/);

    $cmd .= ' -s -c ' . $sat_year;

    ($cmd,$city_descr,\%args);
}


