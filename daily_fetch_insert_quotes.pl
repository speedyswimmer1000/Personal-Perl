#! /usr/bin/perl

use warnings;
use strict;

use LWP::Simple;
use Database;
use Time::HiRes;
use Data::Dumper;

my $start_time = [Time::HiRes::gettimeofday()];

our $main_handle = init('C:\Users\Benjamin\Dropbox\Perl Code\Stock Database AI\final_database', "Information_table");
our $day_handle = init('C:\Users\Benjamin\Dropbox\Perl Code\Stock Database AI\final_database', "Day_table");

## Creates a hash of property tags, according to the Yahoo API, and the assorted comma-delimited category name, to be printed at the top of the 
## CSV file. This hash is accessed through the build_url_link subroutine. 

# Properties - a number of flags that I can put in to get different data from the web.
# From https://code.google.com/p/yahoo-finance-managed/wiki/csvQuotesDownload and
# https://code.google.com/p/yahoo-finance-managed/wiki/enumQuoteProperty
# If a flag becomes invalid, it still fetches the field, but populates it with a blank (instead of a N/A). 
# I can select on that with a regex when I'm scrubbing data, I guess. 
# When built properly, the url constructed will fetch a CSV file.

our %prop_hash = {};
my @sym = ("s0", "Symbol,");
my @last_price = ("l1", "Last Trade Price,");
my @pe = ("r0", "PE Ratio,");
my @quar_eps = ("e9", "EPS Next Quarter,");
my @n_year_eps = ("e8", "EPS Next Year,");
my @c_year_eps = ("e7", "EPS Current Year,");
my @year_high = ("k0", "Year High,");
my @year_low = ("j0", "Year Low,");
my @change_50 = ("m7", "Change from 50day,");
my @change_200 = ("m5", "Change from 200day,");
my @div_date = ("r1", "Dividend Pay Date,");
my @ex_div = ("q0", "Ex Dividend Date,");
my @trail_div = ("y0", "Trailing Dividend Yield %,");
my @tick_tren = ("t7", "Ticker Trend,");
my @hold_gain = ("g4", "Holdings Gain,");
my @ann_gain = ("g3", "Annualized Gain,");
my @book_val = ("b4", "Book Value Per Share,");
my @market_cap = ("j1", "Market Capitalization,");

my @open = ("o0", "Open,");
my @prev_close = ("p0", "Previous Close,");
my @day_high = ("h0", "Day's High,");
my @day_low = ("g0", "Day's Low,");
my @volume = ("v0", "Volume,");
my @change = ("c1", "Change,");
my @change_per = ("p2", "Change in %,");
my @avg_day_vol = ("a2", "Average Daily Volume,");
my @fif_day_avg = ("m3", "50 Day Avg,");
my @short_rat = ("s7", "Short Ratio,");
my @targ_price = ("t8", "One Year Target Price,");
my @exchange = ("x0", "Stock Exchange,");
my @name = ("n0", "Name,");

$prop_hash{"symbol"} = \@sym;
$prop_hash{"last price"} = \@last_price;
$prop_hash{"pe"} = \@pe;
$prop_hash{"quarter eps"} = \@quar_eps;
$prop_hash{"next year eps"} = \@n_year_eps;
$prop_hash{"current year eps"} = \@c_year_eps;
$prop_hash{"year high"} = \@year_high;
$prop_hash{"year low"} = \@year_low;
$prop_hash{"change from 50"} = \@change_50;
$prop_hash{"change from 200"} = \@change_200;
$prop_hash{"dividend date"} = \@div_date;
$prop_hash{"ex dividend"} = \@ex_div;
$prop_hash{"trailing dividend"} = \@trail_div;
$prop_hash{"ticker trend"} = \@tick_tren;
$prop_hash{"hold gain"} = \@hold_gain;
$prop_hash{"annual gain"} = \@ann_gain;
$prop_hash{"book val"} = \@book_val;
$prop_hash{"market cap"} = \@market_cap;
$prop_hash{"open"} = \@open;
$prop_hash{"previous close"} = \@prev_close;
$prop_hash{"day high"} = \@day_high;
$prop_hash{"day low"} = \@day_low;
$prop_hash{"volume"} = \@volume;
$prop_hash{"change"} = \@change;
$prop_hash{"change percent"} = \@change_per;
$prop_hash{"avg daily volume"} = \@avg_day_vol;
$prop_hash{"fifty day avg"} = \@fif_day_avg;
$prop_hash{"short ratio"} = \@short_rat;
$prop_hash{"target price"} = \@targ_price;
$prop_hash{"exchange"} = \@exchange;
$prop_hash{"name"} = \@name;

my $url = "http://download.finance.yahoo.com/d/quotes.csv?s=%40%5EDJI,";

our @tickers = read_column($main_handle, "Symbol");
our $csv_header;

sub build_url_link{
## This routine will not take out duplicates. If you pass in duplicates, the thought is, you've probably already accounted for them elsewhere in a copy-paste setting. 
## Only provides the part of the URL after the stock list. 
	our $prop_string = "&f="; #Beginning of properties string of the URL
	$csv_header = "";
	while (my $property = shift @_){
		$property = lc($property);
		
		if (!exists($prop_hash{$property})){  # Throw out invalid headers with a die. 
			die "Not a valid property.\n";
		}
		
		my @url_list = @{$prop_hash{$property}};  #Dereference value from hash.
		$prop_string .= $url_list[0];
		$csv_header .= $url_list[1];
	}
	$prop_string .= "&e=.csv";  # End of the URL
	#print "Properties: $prop_string\nCSV: $csv_header\n";  #Debug
	
	my @return_vals = ($prop_string, $csv_header);  # Return as an array.
}

#From https://code.google.com/p/yahoo-finance-managed/wiki/enumQuoteProperty

my $end = "&e=.csv"; #Formatting for the download site

##Important init variables

### Data get file for the bulk of the data. 
sub get_day_data{
	my $file = ">today_data.csv";

	open OUT, $file or die $!;


	my @url_data = build_url_link("symbol", "open", "last price", "previous close", "day high", "day low", "volume", "change", "change percent",
								  "avg daily volume", "fifty day avg", "short ratio", "target price", "ticker trend");##, "book val", "market cap");
	our $properties = $url_data[0];
	$csv_header = $url_data[1];
	
	print OUT $csv_header . "\n";
	
	our $records_at_once = 50; # Capped at 50 records at once, could change in time so this is for configurability. 
	while (scalar @tickers > $records_at_once){  #Still have records to process. 
		my $stocks = "";
		for (my $i = 0; $i < $records_at_once - 1; $i++){
			$stocks .= shift(@tickers) . ',';  # Comma separated list of the first 49 stocks
		}
		$stocks .= shift(@tickers); #No comma on the end of the list.
		#print scalar @tickers . "\n"; 
		my $string = $url . $stocks . $properties . $end; #Format the list. 
		#print $string . "\n";

		my $data = get($string) or die "Unable to download";  # Get the data from the net. 
		chomp($data);
		# Eventually, I can split the string on commas and put it directly into the DB.

		print OUT $data . "\n";
		#print scalar @tickers . "\n";
	}
	my $stocks = "";
	
	my $ticker_size = scalar @tickers - 1;
	for (my $i = 0; $i < $ticker_size; $i ++){
		$stocks .= shift(@tickers) . ',';
	}

	$stocks .= shift(@tickers);
	#print $stocks . "\n";
	my $string = $url . $stocks . $properties . $end; #Format the list. 
	my $data = get($string) or die "Unable to download";  # Get the data from the net. 
	chomp($data);
	print OUT $data . "\n"; # To preserve the correct spacing in the .csv file. 
	
	close OUT;

	my $diff = Time::HiRes::tv_interval($start_time);

	print "\n\nFinished fetching data at $diff\n";

	# End wrap ######################

}

sub process_date_csv{

	open IN, "today_data.csv" or die $!;
	use Date::Calc;

	my $garbage = <IN>;
	my $count = 5;

	print "Starting day processing...\n";

	my ($year, $month, $day) = Date::Calc::Today();
	$month = sprintf '%02d', $month;
	$day = sprintf '%02d', $day;
	our $date = "$year/$month/$day"; ## Friendly format of YYYY/MM/DD, better for < > comparisons in ASCII.
	
	our @records_array_of_array = ();
	our @exclude_fields = ("Order_of_entry");
	our @symbols = ();
	our @close = ();
	our @ticker_trends = ();

	while (my $line = <IN>){
		chomp $line;  #Problem: The csv I get out only uses \n, but no \r (UNIX but not Windows format)
		#print "$line\n";
		my @data = split(',', $line);
		my $symbol = shift(@data);
		
		$symbol =~ s/"//g;
		
		my $open = $data[0];
		my $close = $data[1];
		my $prev_close = $data[2];
		my $day_high = $data[3];
		my $day_low = $data[4];
		my $volume = $data[5];
		my $change = $data[6];
		my $change_percent = $data[7];
		
		$change_percent =~ s/"//g;
		
		my $avg_daily_vol = $data[8];
		my $fifty_day_avg = $data[9];
		my $short_ratio = $data[10];
		my $one_year_price = $data[11];# "ticker trend", "book val", "market cap");
		my $tick_trend = $data[12];
		
		$tick_trend =~ s/&nbsp//g;
		$tick_trend =~ s/"//g;
		$tick_trend =~ s/;//g;		
		
		push (@symbols, $symbol);
		push (@close, $close);
		push (@ticker_trends, $tick_trend);
		
		my @handle_num_array = read_field($main_handle, "Symbol", $symbol, "Handle");  # Almost certain I can make this one call and hash it. 
		my $handle_num = $handle_num_array[0][0];
		#print "Handle # is $handle_num\n";
		#print "$handle_num\n";
		#print "$date\n";
		my $oc_change;
		if ($prev_close ne "N/A" and $open ne "N/A"){
			$oc_change = $open - $prev_close; # Change between last close and this open. 
		}else{
			$oc_change = 0;
		}
		$oc_change = sprintf("%.2f", $oc_change);
		
		my @set_up_db = ($symbol, $handle_num, $date, $open, $close, $prev_close, $oc_change, $day_high, $day_low,
						$volume, $change, $change_percent, $avg_daily_vol, $fifty_day_avg, $one_year_price, $short_ratio);
		
		#print join (',', @set_up_db);
		push(@records_array_of_array, \@set_up_db);
		#write_new($day_handle, @set_up_db);
	#	set_erase($main_handle, "Symbol", $symbol, "Close", $close);
	#	set_erase($main_handle, "Symbol", $symbol, "Ticker_trend", $tick_trend);
	#	set_erase($main_handle, "Symbol", $symbol, "Book_val", $book_val);
	#	set_erase($main_handle, "Symbol", $symbol, "Market_cap", $mark_cap);
	}
	
	my $diff = Time::HiRes::tv_interval($start_time);
	print "\n\nCSV parsing finished at $diff\n";
	
	print "Inserting into database...\n";
	
	 
	
	#my $max_at_once = 50;
	#while (scalar @records_array_of_array > $max_at_once){
	#	my @processing_record_array = @records_array_of_array[0..$max_at_once - 1];
	#	splice @records_array_of_array, 0, $max_at_once; # Remove the first $max_at_once elements starting at element 0.
	#	mult_new_records($day_handle, \@exclude_fields, \@processing_record_array);
	#	#print "\nScalar is " . scalar @records_array_of_array . "\n";
	#}
	
	mult_new_records($day_handle, \@exclude_fields, \@records_array_of_array);  # With what's left of the records_a_of_a
	
	$diff = Time::HiRes::tv_interval($start_time);
	print "\n\nInserting new daily records finished after $diff\n";
	
	my @fields = ("Close", "Ticker_trend");
	my @val2 = (\@close, \@ticker_trends);
	update_mult_rows_and_fields($main_handle, \@fields, "Symbol", \@symbols, \@val2);
	
	
	$diff = Time::HiRes::tv_interval($start_time);
	print "\n\nUpdating main table finished at $diff\n";
}

get_day_data();
process_date_csv();

#Next project:
#
# UPDATE Main_table SET Handle=CASE
#   WHEN Symbol='A' THEN 43
#   WHEN Symbol='AA' THEN 36
# END,
# Close = CASE
#   WHEN Symbol='A' THEN 489743534
#   WHEN Symbol='AA' THEN 323643
# END
#WHERE Symbol in ('A', 'AA')
#
####

## Avg time, 6/9, to enter into DB: ~120 sec (constant)
# --Shaved off 4 seconds by not recomputing the date every time. 
# --By splitting fewer fields, I have ~ 114 seconds. 
# -- After inserting the 'Close' and 'Ticker_trend' args, the processing time has shot up to 368 sec. This is an obvious point for optimization in the future. 
# MASSIVE improvement after making it a batch import to the database. I can now write about 4500 records in 5 seconds, including lookups to the main table for handles. (I haven't implemented writing the close, etc.
# 5 seconds, down from 120 for a similar function ==> 96% speedup!!
# Once I add in the set_erase functions, I'm back up to 188 seconds. I need to optimize that next. 

=pod
Best bet: multiple entry, and multiple update of information_table

INSERT INTO Test_table
SELECT 'OKO' AS 'One', 36 AS 'Two'
UNION SELECT 'ONEO', 469
UNION SELECT 'IOM', 36

=cut


# Avg. time, 6/10, to fetch 4500 records: 24 sec. / 23 sec. 