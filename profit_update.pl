#! /usr/bin/perl

use Finance::Quote;
use warnings;
use Bank::Holidays;
use Date::Calc  qw(Delta_Days);
use Database;

our $debug_true = 0;
our $debug_sale_sum = 0;
our $e_code = export_e_code();

our ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

if ($debug_true == 0){   #Check if it's a bank holiday. 
	my $bank = Bank::Holidays->new( date => DateTime->now ); # or any datetime object
	if (($wday > 5 || $mday == 0) || $bank->is_holiday){
		#unlink $ARGV[0];
		#unlink $ARGV[1];
		exit;
	}
}

###############  Stock broker info processing. #############################################
`python login.py tmp1`;

our $main_handle = init('C:\Users\Benjamin\Dropbox\Perl Code\Stock Database AI\final_database', "Information_table");
our $current_handle = init('C:\Users\Benjamin\Dropbox\Perl Code\Stock Database AI\final_database', "Current_shares");
our $sale_handle = init('C:\Users\Benjamin\Dropbox\Perl Code\Stock Database AI\final_database', "Sales");

our $commission = 6.95;

our $share_hist = 'tmp1';  
#our $scott_hist = 'tmp2';  # From a python script. 
#our $quote = Finance::Quote->new();
#our $records = "./record_data.txt";
#our $sales = ">>" . "./sales.txt";
#if ($debug_true == 1){
#	$records = "./record_data_old.txt";
#	$sales = ">>" . "./sales_old.txt";
#}

our $debug = ">../debug.txt";
open DEBUG, $debug or die $!;

$year = $year + 1900;
$mon = $mon + 1;
if ($mday < 10){
	$mday = 0 . $mday;
}
our $today = $mon . "/" . $mday . "/" . $year;
our $YYYYMMDD = $year . "/" . $mon . "/" . $mday;
print DEBUG $today . "\n";

open SHARE, $share_hist or die $!;
#open SCOTT, $scott_hist or die $!;
#open OUT, ">./test" or die $!;

my $share_hist_string;
while (<SHARE>){  #Parse HTML, nasty stuff, etc... 
	chomp ($_);
	$share_hist_string = $share_hist_string . $_;
}
$share_hist_string =~ s/\t//g;
$share_hist_string =~ s/\n//g;
$share_hist_string =~ s/\r//g;

#my $scott_hist_string;
#while (<SCOTT>){
#	chomp ($_);
#	$scott_hist_string = $scott_hist_string . $_;
#}
#$scott_hist_string =~ s/\t//g;
#$scott_hist_string =~ s/\n//g;
#$scott_hist_string =~ s/\r//g;
#$scott_hist_string =~ s/ //g;

close SHARE;
#close SCOTT;

our @share_hist_data;
#Sharebuilder transaction record history parsing.
while ($share_hist_string =~ m/(TransactionHistory_ct(.*?)_strDate.*?tr>)/g){
print DEBUG "START\n$1\nEND";
#print "$1\n";
#Needs this regex to get down to the last line on the table and to get all the relevant data (hence the duplicate .*?\%\)<\/span><\/td>)
	#print OUT "\n" . $1 . "\n\nOK\n\n";
	my $line = $1;  # Get the appropriate line and regex it. 
	$line =~ m/strDate\"\ class=\"Date\">(.*?)\<\//g;
	my $date = $1;
	print "$date\n";
	$date =~ s/^0//g;  #Get the date. 
	if ($date ne $today) {
		print DEBUG "NEXT\n";
		next;
	}  #The transaction didn't take place today, so we're good. Exit loop.
	$line =~ m/strAction\"\>(.*?)\<\/span/g;
	my $action = $1;
	print DEBUG "$action\n";
	print "$action\n";
	if ($action eq "MTD" or $action eq "FTX" or $action eq "DIVIDEND" or $action eq "FCI" or $action eq "STD" or $action eq "SPC" or $action eq "MTW"){
	#Catch-all for throwing out non-stock transactions, which don't have anything to do with it. Skip to next iteration.
		print DEBUG "Not a related stock action -- Next\n";
		next;
	}
	$line =~ m/strSymbol\"\>(.*?)\<\/span/g;
	my $stock_symbol = $1;
	$line =~ m/strQuantity\"(.*?)\<\/span/g;
	my $shares_transacted = $1;
	$shares_transacted =~ s/( class="Neg"|\>)//g;  # Regexes to clean up. 
	$shares_transacted = &shares_clean($shares_transacted);
#	$shares_transacted = abs($shares_transacted);
	$line =~ m/strPrice\"\>(.*?)\<\/span/g;
	my $price_per_share = $1;
	$price_per_share = &price_clean($price_per_share);
	print $price_per_share . "\n";
	$line =~ m/strAmount\"(.*?)\<\/span/g;
	my $total_cost_or_gain = $1;
	$total_cost_or_gain =~ s/( class=\"Neg\"|\>|\$|,)//g;  # Looks for commas, dollar signs, '>', or "class="Neg" and takes them out.
	$total_cost_or_gain = &shares_clean($total_cost_or_gain);
	
	if ($action ne "DRV"){
		$shares_transacted = abs($shares_transacted); # Because I don't want to break what I had going in other areas, but DRV needs to be able to tell if there was a positive or negative because sharebuilder messes up at times. 
		$total_cost_or_gain = abs($total_cost_or_gain);
	}else{
		$total_cost_or_gain *= -1;  # Because it's negative investment and should be positive gain... IDK.
	}
	
	my @transaction_record = ($stock_symbol, $action, $shares_transacted, $price_per_share, $total_cost_or_gain);
	#Symbol should be all Caps. Action should be BUY, SELL, or DRV. Shares_transacted is positive.
	#Price per share is just there for show. Total_cost_or_gain is given in terms of absolute value. 
	print DEBUG "   " . join (',   ', @transaction_record) . "\n";
	#print  "   " . join (',   ', @transaction_record) . "\n";
	push (@share_hist_data, \@transaction_record);  # An array of references to arrays, with clean data. This should be OK. 
}

#Scottrade history parsing
#GUARANTEED to be buggy! I'm still figuring out the format here. 
## Closed the scottrade account, not planning on going back, so unless I do, I'm not planning on parsing that further. 
=pod
while ($scott_hist_string =~ m/(rptCompletedOrders.*?SettlementDate.*?\<\/)/g){
	my $line = $1;
	if($line !~ m/symbol/g){  next;}
	#print OUT "\n\nHERE IT IS!! \n\n\n$line";
	$line =~ m/lblTradeDate\"\>(.*?)\<\//;
	my $date = $1;
	if ($date ne $today)  {next;}
	$line =~ m/symbol=.*?\"\>(.*?)\<\//;
	my $stock_symbol = $1;
	$line =~ m/lblAction\"\>(.*?)\<\//;
	my $action = $1;
	$line =~ m/lblQuantity\"\>(.*?)\<\//;
	my $shares_transacted = $1;
	$shares_transacted = &price_clean($shares_transacted);
	$line =~ m/lblPrice\"\>(.*?)\<\//;
	my $price_per_share = $1;
	$price_per_share = &price_clean($price_per_share);
	$line =~ m/lblTotal\"\>(.*?)\<\//;
	my $total_cost_or_gain = $1;  #This may need a negative or positive to correspond well with my sharebuilder standard. 
	$total_cost_or_gain = &price_clean($total_cost_or_gain);
	if ($action eq "Bought"){
		$action = "BUY";
	}
	if ($action eq "Sold"){
		$action = "SELL";
	}
	$total_cost_or_gain = abs($total_cost_or_gain);
	#As I use this more, I need to add other modifiers for Sales, Dividends (?), non transactions, etc. 
	my @transaction_record = ($stock_symbol, $action, $shares_transacted, $price_per_share, $total_cost_or_gain);
	#Symbol should be all Caps. Action should be BUY, SELL, or DRV. Shares_transacted is positive.
	#Price per share is just there for show. Total_cost_or_gain is given in terms of absolute value. 
	print DEBUG join (', ', @transaction_record) . "\n";
	push (@share_hist_data, \@transaction_record);
}

=cut

#OK, good. I have an array of transaction objects. Now I need to use my stock_update architecture to update text files. 

#############JOINED HERE#############################
#open RECORD, $records or die $!;
#open SALES, $sales or die $!;

#Things I shouldn't have to worry about with this automation: 
# 1 - Getting bogus stock symbols, bogus prices (-3.00/share, e.g.), and generally inaccurate data
# 2 - If all goes as planned, selling what I don't have, but I've built in catches for that.
# I think most of my potential problems are going to be just passing in the arrays of history data. 
# I don't have to worry about changing brokerage fees. That's just in the sum total.

our @tickers = read_column($current_handle, "Symbol");  ## Get a list of all the values I have. 

our %record_hash;
while ($symbol = shift (@tickers) ){  # Get the next symbol from the list and process it. 
#	chomp ($_);
#	$_ =~ m/([A-Z]+)/;
#	my $symbol = $1;
#	my $shares = <RECORD>;
#	chomp ($shares);
#	my $paid = <RECORD>;
#	chomp($paid);
	my $shares = read_field_one_val($current_handle, "Symbol", $symbol, "Num_shares");
	my $paid = read_field_one_val($current_handle, "Symbol", $symbol, "Paid");
	#print "$shares\n$paid\n$symbol\n*****\n";
	my @vals = ($shares, $paid);
	$record_hash{$symbol} = \@vals;
}
#close RECORD;

our $array_size = @share_hist_data;

print DEBUG "Number of transactions to process today is: $array_size\n";

# In this for loop, for the most part, the values are kept in a hash, which makes the portability kind of nice. 

for (my $i = $array_size - 1; $i >= 0; $i--){  #Done in reverse order so that a sale before a rebuy won't confuse it to no end.
	our @ta = @{$share_hist_data[$i]};  #Stands for "Transaction array", in case you wanted to know.
	print DEBUG join(', ',@ta) . "\n";
	#print join(', ',@ta) . "\n";
	#my @transaction_record = ($stock_symbol, $action, $shares_transacted, $price_per_share, $total_cost_or_gain);
	#Symbol should be all caps. Action should be BUY, SELL, or DRV. Shares_transacted is positive.
	#Price per share is just there for show. Total_cost_or_gain is given in terms of absolute value. 
	
	## Unpack data
	my $symbol = $ta[0];
	my $action = $ta[1];
	my $shares_transacted = $ta[2];
	my $price_share = $ta[3];
	my $cost = $ta[4];
	
	## Make sure that the record I'm processing is one that I have record of. If not, it's going to add in a new record... somewhere...
	if (exists $record_hash{$symbol}){
		our @record = @{$record_hash{$symbol}};	
		delete $record_hash{$symbol};  ##REMEMBER TO ADD THIS BACK IN EVERY TIME!!! ####  // Not sure what I meant by that. 
	}
	# @record = $shares ,$paid
	# If it doesn't exist, I'm going to start making a record for it. 
	elsif ($action eq "BUY" or $action eq "DRV"){
		our @record = (0, 0);
	}
	else{
		if ($debug_true == 0){  # Send an uber-helpful error email...
			`email.exe The stock update program has encountered an error: It is trying to sell a stock which you no longer own. Please remedy this manually.`;
			exit;
		}
	}
	if ($action eq "BUY"){
		print "Buy\n";
		my $new_num_shares = $shares_transacted + $record[0];
		my $total_spent = $cost + $record[1];
		my @vals = ($new_num_shares, $total_spent);
		# Add back in to the hash. 
		$record_hash{$symbol} = \@vals;
	}
	elsif ($action eq "SELL"){
		#print "Sell";
		# Message to build on here. 
		our $message = "Just so you know, there is something wrong with your auto stock update program. Probable causes are that you have left your script unrun for a little while and the records are out of date.";
		if ($record[0] eq ""){  #This stock is not in my list. 
			$message = $message . "\n\nThe stock $symbol is not in the list but is listed as being sold on your brokerage account.";
			$message = $message . "\n\nPlease remedy this by hand and rerun this script.";
			if ($debug_true == 0){
				`email.exe $message` and die $!;  #Send an email to me to let me know that something is amiss. This should make this script totally self-monitoring.
			}
		}
		my $owned_shares = $record[0];
		if ($shares_transacted > $owned_shares){  #I'm trying to sell more than I have record of. Error. 
			print "$symbol Too many shares!\n$shares_transacted, $owned_shares";
			print DEBUG "$symbol Too many shares!\n$shares_transacted, $owned_shares";
			$message = $message . "\n\n\tYou are trying to sell more shares than you currently own. ";
			$message = $message . "According to the record, you own $owned_shares of $symbol, but you are trying to sell " . abs($shares_transacted) . ".";
			if ($debug_true == 0){
				`email.exe $message` and die $!;
			}
		}
		our $percent_sold = $shares_transacted / $owned_shares;  #This equals one when all shares are sold.
		print DEBUG "$symbol : " . 100 * $percent_sold. "% was sold. $shares_transacted shares were sold, out of the $owned_shares shares you own.\n";
		my $percent_paid = $percent_sold * $record[1];
		my $profit = $cost - $percent_paid; # Or technically, this could be a loss, but I like to keep it optimistic.
		&clip2($profit);
		if ($debug_true == 0){
		## Write it back to the database, now...
		#	print SALES $profit . "\t" . $symbol . "\n";
			write_new($sale_handle, $symbol, $profit, $YYYYMMDD, "-"); # The date format for "Today" won't matter much... will it? Better put it in YYYYMMDD, to be safe. Line ~40. 
		}else{
			$debug_sale_sum += $profit;
		}
		if ($percent_sold != 1){  # Didn't sell all of it...
			my $shares_left = $owned_shares - $shares_transacted;  #Calculate the number of remaining shares.
			my $paid_left = (1-$percent_sold) * $record[1];  #Calculate how much I paid for the remaining shares
			&clip2($paid_left);
			print DEBUG "Not all shares were sold. " . $paid_left . "\n $profit";
			my @vals = ($shares_left, $paid_left);
			$record_hash{$symbol} = \@vals;  # Push it back onto the hash. Will be written back later.
		}else{ # Sold everything
		print "Deleting...\n";
			delete_row($current_handle, "Symbol", $symbol);
		}
	}
	elsif ($action eq "DRV"){
		print "DRV";
		&clip2($cost);
		if ($debug_true == 0){
			#print SALES "##" . $cost . "\t" . $symbol . "\tDividend\n";  #Effectively was adding in the dividend twice.
			write_new($sale_handle, $symbol, $cost, $YYYYMMDD, "Y"); # IIRC, $cost here is the value of the dividend. In my algorithm, dividends don't count as being paid... Free stock + a sale, basically.
		}
		else{
			$debug_sale_sum += $cost;
		}
		my $new_num_shares = $shares_transacted + $record[0];
		#print "\nDRV Data: $new_num_shares $symbol $shares_transacted\n";
		my @vals = ($new_num_shares, $record[1]); # So it doesn't update the paid price here...
		$record_hash{$symbol} = \@vals;
	}
}
#close SALES;
#Print our record hash back out now. 

#if ($debug_true == 0){
	#open RECORD_OUT, ">" . $records or die $!; # I think this just has to do with writing back to my DB now. 
#}

our $total_paid;  # Total paid for all stocks as of today.
our $total_worth_today; # Grand total for the day that is this.

print DEBUG "Totals worth today, for each stock:\n";

foreach my $symbol (keys %record_hash){
	my @position = @{$record_hash{$symbol}};
	&clip4($position[0]);  # Number of shares
	&clip2($position[1]);  # Total paid for this stock.
	#print "$symbol";
	#print $position[0];
	#print $position[1];
	#%price = $quote->fetch('nyse',$symbol);
	$total_paid += $position[1];
	$close = read_field_one_val($main_handle, "Symbol", $symbol, "Close");
	#print $price{$symbol, 'price'};
	if (debug_true ne 0){
		print $symbol . " " . $ close . "\n";
	}
	my $current_stock_value = $close * $position[0];
	my $gain_loss = $current_stock_value - $position[1];
	my $sell_price = ($position[1] + $commission) / $position[0];
	$total_worth_today += $current_stock_value;  ## Total sum of all stocks today, *not* current value of stock.
	
	#Formatting 
	$current_stock_value = sprintf '%.2f', $current_stock_value;
	$gain_loss = sprintf '%.2f', $gain_loss;
	$sell_price = sprintf '%.2f', $sell_price;
	#print "$symbol\n$close\n$current_stock_value\n$gain_loss";

	print DEBUG "$symbol  " . $close * $position[0] . "\n";
	#position arrays are ($price, $num_shares, $paid (total))
	if ($debug_true == 0){
	#	print RECORD_OUT "$symbol\n";  #Print the symbol
	#	print RECORD_OUT "$position[0]\n";  # Print how many shares I own
	#	print RECORD_OUT "$position[1]\n";  # Print how much I paid for it.
		# I only want to write here if the symbol already exists... 
		if (search_val($current_handle, "Symbol", $symbol) ne $e_code){  # Already in database
			set_erase($current_handle, "Symbol", $symbol, "Num_shares", $position[0]);
			set_erase($current_handle, "Symbol", $symbol, "Paid", $position[1]);
			set_erase($current_handle, "Symbol", $symbol, "Close", $close);
			set_erase($current_handle, "Symbol", $symbol, "Current_value", $current_stock_value);
			set_erase($current_handle, "Symbol", $symbol, "Gain_loss", $gain_loss);
			set_erase($current_handle, "Symbol", $symbol, "Sell_price", $sell_price);
		}else{
			# Not in database, write a new record.
			write_new($current_handle, $symbol, $close, $position[0], $position[1], $current_stock_value, $gain_loss, $sell_price);
		}
	}
}

#close RECORD_OUT;
&clip2($total_worth_today);
print "$total_worth_today\n$total_paid\n";

our $sales_recorded = 0;
if ($debug_true != 0){
	$sales_recorded = $debug_sale_sum;
}
#if ($debug_true == 0){
#	open SALES, "./sales.txt" or die $!;
#}
#else{
#	open SALES, "./sales_old.txt" or die $!;
#}
#	while (<SALES>){
#		print DEBUG $_;
#		$_ =~ s/(\d+\.\d+).*/$1/g;  # Doesn't get rid of # in front.
#		if ($_ !~ s/^#/g/){  # Oh, if it's NOT preceded by a #.
#			$sales_recorded += $_;
#		}
#	}
#@sales_rec = read_column($sale_handle, "Profit_loss");
#for ( @sales_rec){
#	$sales_recorded += $_;
#}
$sales_recorded = sum_col_w_args($sale_handle, "Profit_loss", "Is_dividend", "ISNOT", 'Y');
print "Sales are $sales_recorded\n";
print DEBUG "\n\nSales you have recorded up til now total \$$sales_recorded\n";

#print "$total_paid \t $total_worth_today";
my $profit = $total_worth_today - $total_paid + $sales_recorded;
&clip2($profit);
#print "\t\t Profit is $profit\n";
#close SALES;

open LOGS, "./logs.txt" or die $!;
our $last;
while (<LOGS>){
    $last = $_ if eof;
}
close LOGS;


#Gets the net from yesterday, off the previously found last line.
our $yesterday_gain = 0;
if ($last =~ /Total Net: \$(.*?)\t/){
    $yesterday_gain = $1;
}  

our $year_start = 2971.15;
#Net gain/loss at the beginning of year, defined as my gain/loss of Dec. 31 (or last trading day of year)
our $day_change = $profit - $yesterday_gain;
&clip2($day_change);
our @start_date = (2012,12,5);
our @today = ($year, $mon, $mday);
our $date_diff = Delta_Days(@start_date, @today);
our $daily_avg = ($profit + 4206.05)/$date_diff;  # This is our daily average since I began keeping track of my returns, and won't change yearly.
&clip2($daily_avg);

our $percent_gain_in_year = ($profit - $year_start)/30000 * 100;  # Rough estimate, I should figure this out...
&clip2($percent_gain_in_year);

if ($debug_true == 1){
	my $prof = ($profit - $year_start);
	print DEBUG "\nPercent gain calculations: Profit is " . $profit . " and percent gain is %" . $percent_gain_in_year . "\n";
}

our $output = "$today : \tDay Change: \$$day_change\tTotal Net: \$$profit\tTotal Invested: \$$total_worth_today\tAvg_gain: $daily_avg\tPercent_gain_year: $percent_gain_in_year\%\n";
open LOGS, ">>./logs.txt" or die $!;
if ($debug_true == 0){
	print LOGS $output;
#	unlink $scott_hist;
	unlink $share_hist;
}

print "Change today is \$$day_change and total profit is \$$profit.\n";

=pod
##DEBUG COMPARISON REGRESSION##
#open CMP_LOG, "../logs.txt" or die $_;
#our $last2;
#while (<CMP_LOG>){
#	$last2 = $_ if eof;
#}
#close CMP_LOG;
#$last2 =~ m/Total Net:.*?(-?\d+\.\d+)\s/;
#my $cmp_profit = $1;
#print DEBUG "Comparison profit was $cmp_profit \n";
#my $margin = 0.05;
# if (not($profit <= $cmp_profit + $margin and $profit >= $cmp_profit -  $margin)){
	# print "NoK";
	# if ($debug_true == 0){
		# `email.exe The regression test has failed. The automatic script says that your profit today is \$$profit, but the managed script says that it is \$$cmp_profit. Look into this! :)`;
		# die $!;
	# }
	# print "The regression test has failed. The automatic script says that your profit today is \$$profit, but the managed script says that it is \$$cmp_profit. Look into this! :)\n";
# }
##END REGRESSION
=cut

close DEBUG;

sub clip2($){
	$_[0] =~ s/^(-?[0-9]+)$/$1\.00/g;  #Make sure I have the decimal point
	$_[0] .= '00';					#Add a few extra zeroes
	$_[0] =~ s/(.*?\.[0-9]{2}).*/$1/g;
	return $_[0];
}
sub clip4($){
	$_[0] =~ s/^([0-9]+)$/$1\.0000/g;
	$_[0] .= '0000';
	$_[0] =~ s/([0-9]+\.[0-9]{4}).*/$1/g;
	return $_[0];
}

sub price_clean($){
#For prices and shares.
	#print $_[0];
	my $temp = $_[0];
	$temp =~ s/(,|\$)//g;
	$temp = abs($temp);
	return $temp;
}

sub shares_clean($){
#For prices and shares.
	#print $_[0];
	my $temp = $_[0];
	$temp =~ s/(,|\$)//g;
	return $temp;
}