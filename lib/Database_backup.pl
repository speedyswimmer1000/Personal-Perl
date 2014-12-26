#! /usr/bin/perl

package Database;  # So, now that this is in the perl path, it has to be named 'Database' instead of 'lib::Database', for some reason. 
use strict;
use warnings;
use vars qw($table @valid_fields $name_field $dbhandle $database_file %db_head_hash $tag_num $last_instance);  # Syntax for global variables.
our @EXPORT = qw(init about export_e_code del_all_table mult_new_records info write_new read_all_data sum_col_w_args read_field read_field_one_val return_table_headers set_multiple_fields set_erase read_column search_val delete_row number_of_records); # A list of all functions - global vars also can go here.

require Exporter;
use Data::Dumper;
use POSIX; # For floor() functionality.

use Exporter qw(import);
our @ISA = qw(Exporter); #Inherited method for passing package name
# use Sub::Exporter -setup => {
    # exports => [ qw/init write_new read_all_data read_field exists erase delete_row append/ ],
# };
 
#use Finance::Quote;  #Deprecated on my system now; I got my IP address blocked after using it to scrape, oh, 100k records in a day, I think... :)
#Database modules
use DBI;
use Scalar::Util qw(looks_like_number);  #Checks that something looks like a number. 
use List::MoreUtils qw/any/; # Used to parse through and see if a value is in an array.
use warnings;
use strict;

$last_instance = -1;
$tag_num = 0;  # Increasing count variable, reference to the top level hash. It is the instance number of the table you're reading.
our $e_code = -1;
%db_head_hash = ();
# our $table;
# our @valid_fields;
# our $name_field;
# our $dbhandle;

sub export_e_code{
	return $e_code;
}

sub about{
#w(      read_all_data read_field return_table_headers
# set_erase read_column search_val delete_row number_of_records
printf("%-15s  %-15s  %-46s", "Function:", "Args:", "Description:");
printf("%-15s  %-15s  %-46s", "about", "<none>", "This function prints out data and parameters");
printf("%-15s  %-15s  %-46s", "               ", "               ", "for all the functions in this perl module.   ");
print "\n";
printf("%-15s  %-15s  %-46s", "init           ", "\$dbfile, \$table", "Initialize a database handle, valid fields   ");
printf("%-15s  %-15s  %-46s", "               ", "               ", "array, and a unique key in a hash for valid  ");
printf("%-15s  %-15s  %-46s", "               ", "               ", "parameters.                                  ");
print "\n";
#printf("%-16s  %-14s  %-46s", "set_pkg_instance", "\$db_handle     ", "Restore all handles, valid fields, and other");
#printf("%-15s  %-15s  %-46s", " <INTERNAL>    ", "               ", "variables necessary for proper function of   ");
#printf("%-15s  %-15s  %-46s", "               ", "               ", "the database module on a given handle.       ");
#print "\n";
printf("%-15s  %-15s  %-46s", "del_all_table  ", "\$db_handle and", "Delete all contents in the given table for   ");
printf("%-15s  %-15s  %-46s", "               ", "security vars  ", "a fresh start.                               ");
print "\n";
printf("%-15s  %-15s  %-46s", "info           ", "\$db_handle    ", "Print out info on the selected database      ");
print "\n";
printf("%-15s  %-15s  %-46s", "export_e_code  ", "<none>         ", "Export error code, for consistency when      ");
printf("%-15s  %-15s  %-46s", "               ", "               ", "checking for invalid operations.             ");
print "\n";
printf("%-15s  %-15s  %-46s", "write_new      ", "\$db_handle,   ", "Write a new record to the selected table.    ");
printf("%-15s  %-15s  %-45s", "               ", "\@exclude_fields,", "Fields that you don't wish to write to may  ");
printf("%-15s  %-15s  %-46s", "               ", "\@vals         ", "be prepended with a \"-\", at the beginning of ");
printf("%-15s  %-15s  %-46s", "               ", "               ", "the list of arguments to insert. Checks to   ");
printf("%-15s  %-15s  %-46s", "               ", "               ", "ensure that the # of args matches # columns. ");
print "\n";
print "To be continued...\n";
}

sub init{
	#Arguments: Database file and $table
	my %instance_hash;
	#	&what_db_current();
	#print join(',', @_) . "\n";
	if (scalar @_ != 2){
		return $e_code;
	}
	$database_file = $_[0];
	$table = $_[1]; #Table in the database
	# Now, the problem is that I've overwritten these two variables, and unless I reset them, I won't know that they've been erased from my working memory 
	# (i.e. for the purposes of my set_pkg_instance function)
	my $key = $database_file . $table;  # This will be a unique key to the hash. I can use it on the next line to see if I've already defined this key.
	if (exists($db_head_hash{$key})){
		#print "This key already exists.\n\n";
		$last_instance = "";
		return $key;
	}
	
	# At this point, I'm sure that it's a valid request that isn't in my hash, but I don't know if it's a valid database. 
	
	chomp($table, $database_file);
	if (&scrub($table) == $e_code){
		$last_instance = "";
		return $e_code;
	}
	
	unless (-r $database_file){  # Checks if the file exists
		#print "This database file does not exist.\n";
		$last_instance = "";
		return $e_code;
	}
	$dbhandle = DBI->connect("dbi:SQLite:dbname=" . $database_file, "", "", {RaiseError => 1}) or return "Does not exist";
	
	# Not catching anything here... probably because it connects and creates a database like this.  
	
	# It's important that $dbhandle be global to ensure proper function of subroutines, such as exists().

	######IMPORTANT #####################################################################################

	my $sql_quer = qq/PRAGMA table_info(/ . $table . qq/)/;
	#print $sql_quer . "\n";
	my $statement_handle = $dbhandle->prepare($sql_quer);
	$statement_handle->execute();
	
	@valid_fields = ();  # Put this here after determining that we have a distinct database so that I don't accidentally overwrite (caught in bug testing)
	# Put here, just before use, so I can't screw it up again.
	
	while (my @data = $statement_handle->fetchrow_array()) {
		my $string =  $data[1];
		#print $string;
		push (@valid_fields, $string);
		#print "\n";
	}
	#print join(',',@valid_fields) . "\n";
	$name_field = $valid_fields[1]; #I'm not recalling why I put this here. 
	if (!defined($name_field)){
		$last_instance = "";
		#print "This name field not valid\n";
		return $e_code;
	}
	
	################
	## TODO: Figure out how to validate this more
	################
	
	my @fields = @valid_fields; # Used to provide a local copy. Otherwise, all the references I push into the array will get updated every time I nuke @valid_fields. 
	$instance_hash{'db_handle'} = $dbhandle;
	#$instance_hash{'name_field'} = $name_field;
	$instance_hash{'table'} = $table;
	$instance_hash{'database_file'} = $database_file;
	$instance_hash{'valid_fields'} = \@fields; 
	
	$db_head_hash{$key} = \%instance_hash;
	
	$last_instance = $key;
	return $key; # Doesn't increment until the pointer is initialized.
}

sub set_pkg_instance{ #Unpack all variables from the global hash that are related to this instance, since perl OO programming is a beast...
# I'm not sure what I can do here to test this module other than use it.
# This function is internal to the module, not visible to the outside.  
	my $ref = $_[0];
	chomp $ref;
	#print "Beginning of set package\n";
	#&what_db_current();
	if ($ref ne $last_instance){  # No need to unpack all this unless I'm sure that it needs to be so. 
		my $hash_ref;
		if (exists($db_head_hash{$ref})){
			$hash_ref = $db_head_hash{$ref};
		}else{
			return $e_code;
		}
		#print "Resetting...\n";
		my %hash = %$hash_ref;
		$dbhandle = $hash{'db_handle'}; # I know that this probably isn't kosher to keep using a global here, but this makes it so subroutines won't go funky. 
		$table = $hash{'table'};
		$database_file = $hash{'database_file'};
		my $fields_ref = $hash{'valid_fields'};
		@valid_fields = @$fields_ref;  # Not working...
		
		$last_instance = $ref;
	#	&what_db_current();
	#	print "End of set package\n";
		return 1;
	}
}

sub del_all_table{  ## Asks for $e_code twice because basically I don't want to nuke the database without being 
					#  absolutely sure I want to delete it. 
					# Format: $e_code, $handle, "Yes", "Delete".
	my $verification = shift(@_);
	if ($verification != $e_code){
		return $e_code;
	}
	my $ref = shift(@_);
	if (set_pkg_instance($ref) == $e_code){
		return $e_code;
	}
	$verification = shift(@_);
	if ($verification !~ m/YES/i){
		return $e_code;
	}
	$verification = shift(@_);
	if ($verification !~ m/Delete/i){
		return $e_code;
	}
	my $sql_quer = qq/DELETE FROM / . $table;
	#print $sql_quer . "\n";
	#print join(',',@_copy) . "\n";
	my $sub_state_handle = $dbhandle->prepare($sql_quer);
	$sub_state_handle->execute() or die $DBI::errstr;
}

sub what_db_current{
## Debug function, sort of a Data::Dumper for my own structures. 
	print "\n\n#####  Printing the current handle information...  #####\n\n";
	print "DB handle is: \t\t" .$dbhandle . "\n";
	print "Table is: \t\t" . $table . "\n";
	print "Database file is: \t" . $database_file . "\n";
	print "Valid fields are: \t" . join(',', @valid_fields) . "\n";
	print "Last instance name is: \t" . $last_instance . "\n";
	print "\n##########################################################\n\n";
}

sub info{
	my $ref = $_[0];
	chomp $ref;
	#looks_like_number($ref) or return $e_code;
	if (!exists($db_head_hash{$ref})){
		return $e_code;
	}
	my $hash_ref;
	if (exists($db_head_hash{$ref})){
		$hash_ref = $db_head_hash{$ref};
	}else{
		return $e_code;
	}
	my $name = $db_head_hash{$ref}{'table'};
	my %hash = %$hash_ref;
	#print Dumper(\%hash);
	#print $name . "\n";
}

sub scrub{ # Used to prevent SQL injection attacks, of a sort.
# Not visible to outside modules, but I think it works. I should test this more. 
	my $data = $_[0];
	chomp $data;
	if ($data =~ m/[^A-Za-z0-9_]/){
		#print "The string " . $data . " is not a valid string for this argument. $!\n";
		return $e_code;
	}
}

###

# Field control. Now that I'm using enums, this is critical to use these fields here and nowhere else.  //Is this true?

## Not used =>
		#use enum qw(       Symbol    Dates    Price    Volume    High    Low    Relative Strength    5 Day Moving    20 Day Moving    MACD    Bought and Liked    Industry);
		#our $fields = qq/("Symbol", "Dates", "Price", "Volume", "High", "Low", "Relative Strength", "5 Day Moving", "20 Day Moving", "MACD", "Bought and Liked", "Industry")/; #Used in read_field
		#our @valid_fields = qw/Symbol Dates   Price    Volume    High    Low    Relative Strength    5 Day Moving    20 Day Moving    MACD    Bought and Liked    Industry)/;
		#our @fields_text = ("price", "volume", "high", "low", "Relative Strength", "5 Day Moving", "20 Day Moving", "MACD", "Bought and Liked", "Industry");  # May not need this.
#our @db_fields;
#our ($symbol,  $date,   $price,  $volume,  $high,  $low, $rel_strength, $five_day, $twenty_day, $MACD, $bought_liked, $industry);
#sub decode(){
#				($symbol,  $date,   $price,  $volume,  $high,  $low) = @db_fields;
#}
################  IMPORTANT ABOVE #################################################################

###########################################################################

#Method to prevent data conflict

sub is_valid_field{
#Used to ensure that I'm writing to a field that exists in the current table.
	my %params = map{$_ => 1 } @valid_fields;
	my $test = $_[0];
	#print "Test is " . $test . "\n";
	chomp ($test);
	if (exists($params{$test})){
		return $e_code + 1;
	}
	else{ 
		return $e_code;
	}
}

sub write_new{  #Writes a new record, not a new column. #Probably will just be renamed to 'write'
## This one is going to be rather tricky...
#Never mind.
# In this module, duplicate records are perfectly OK, and I won't check that it already exists. 
# If I want to exclude a field from writing, I pass it in in the front of the command list with a '-' prepended.
# The module requires that I list all fields I want to exclude passing parameters for, then the parameters.
# The parameters that I do want to pass still have to be in the correct order. 
	my $ref = shift(@_);
	if (set_pkg_instance($ref) == $e_code){
		return $e_code;
	}
	
	#what_db_current();
	
	if (scalar @_ != scalar @valid_fields){ # Then I'm trying to put the wrong number of elements in the new record.
	# @_ is the fields I want to write, @valid_fields is the titles of the table columns.
	  # It's not going to be up to this module to check that you're putting things in the right place; I'm just checking that it will put the right number of things.
	  # It may be possible to check what the field expects to be (number, string, etc) but I don't know how to do that - yet. 
	  # Future development, maybe. 
		return $e_code;
	}
	
	my $fields = " (" . join(', ', @valid_fields) . ") ";  # Format the MySQL Query
	
#	print join(',', @_);
	
	my $retracted = 0; # Number of fields that I take out by argument. 
	while ($_[0] =~ m/(-.?)/){  ## Won't work - what if it's a number? ## looks_like_number.
		my $column = shift(@_);
		#print "\n$column\n";
		#$column =~ m/(-.*)/; 
		#$column = $1;
	#	print $column . "\t\t";  # I don't need to regex for it again, since I know that it's going to either be
								# a column name or be invalid.
		
		$column =~ s/^-//g;
		if (is_valid_field($column) != $e_code){
			$fields =~ s/$column, //g;
			$fields =~ s/$column//g; ## In case it's at the end of the fields list. 
		#	print $fields . "\n";
		}
		else{
			#print "Invalid field\n";
			return $e_code;
		}
	#	print $fields . "\n";
		$retracted++;
		if ($retracted == scalar @valid_fields){ #Corner case, in case you're taking out all the fields
			my $sql_quer = qq/INSERT INTO / . $table . ' (' . $valid_fields[0] . qq/) values (?)/ ;	
			#print $sql_quer . "\n";
			my $sub_state_handle = $dbhandle->prepare($sql_quer);
			$sub_state_handle->execute(undef) or die $DBI::errstr;	
			return $e_code + 1;
		}
	}
	
	my @_copy;# = @_;
	#print join(',',@_copy) . " is at_copy\n\n";

	my $question_marks = "(";   # You need a comma separated string of question marks to populate the query and pass in data. 
	for (my $j = 0; $j < ((scalar @valid_fields) - $retracted); $j++){
		if ($_[$j] =~ m/^NULL$/i){
			$question_marks .= "NULL";
		}else{
			$question_marks .= "?";
			push(@_copy, $_[$j]);
		}
		if ($j != scalar @valid_fields - 1 - $retracted){
			$question_marks .= ", ";
		}
	}
	$question_marks .= ")";
	
	for (my $i = 0; $i < scalar @_copy; $i++){
		$_copy[$i] =~ s/"//g;
	}
	
	my $sql_quer = qq/INSERT INTO / . $table . ' ' . $fields . qq/VALUES / . $question_marks;
	#print $sql_quer . "\n";
	#print join(',',@_copy) . "\n";
	my $sub_state_handle = $dbhandle->prepare($sql_quer);
	$sub_state_handle->execute(@_copy) or die $DBI::errstr;	
}

sub mult_new_records{
# Insert many new records into the database. 
# Parameters: $dbhandle, @array_fields_exclude, @@array_of_arrays (Array of arrays of elements to add)
## Null elements are not supported yet. 
#print "\nNumber of args is " . scalar @_ . "\n";
	if (scalar @_ != 3){
		return $e_code;
	}
	my $ref = shift(@_);
	if (set_pkg_instance($ref) == $e_code){
		return $e_code;
	}
	
	my @exclude_array = @{shift(@_)};
	my @records_array = @{shift(@_)};
	
	my $SQL_LITE_MAX = 999;  # Maximum number of bind vars, defined in SQLite spec. 
	my $fields_in_record = scalar @{$records_array[0]};  # How many non-null fields are in each record. 
	my $max_at_once = floor($SQL_LITE_MAX / $fields_in_record);
	my $fields = " (" . join(', ', @valid_fields) . ") ";  # Format the MySQL Query
	my $retracted = 0; # Number of fields that I take out by argument. 
	
	for( my $i = 0; $i < scalar @exclude_array; $i++){
		my $column = $exclude_array[$i];
		
		if (is_valid_field($column) != $e_code){
			$fields =~ s/$column, //g;
			$fields =~ s/$column//g; ## In case it's at the end of the fields list. 
		#	print $fields . "\n";
		}
		else{
			return $e_code;
		}
		$retracted++;
		if ($retracted == scalar @valid_fields){ #Corner case, in case you're taking out all the fields
			my $sql_quer = qq/INSERT INTO / . $table . ' (' . $valid_fields[0] . qq/) values (?)/ ;	
			#print $sql_quer . "\n";
			my $sub_state_handle = $dbhandle->prepare($sql_quer);
			$sub_state_handle->execute(undef) or die $DBI::errstr;	
			return $e_code + 1;
		}
	}
	
	## INSERT INTO Test_table 
    ## SELECT "AAA" AS ONE, 4364 AS TWO
	## UNION SELECT "BBB", 36
=pod
INSERT INTO Test_table
  SELECT "ddCAC" AS One, NULL AS TWO
UNION SELECT "DddGD", NULL
UNION SELECT "ryrs", NULL
=cut
#//Wrap here...
	our @fields = split( ',', $fields);
	#print join(',', @fields) . "\n";
	our $num_fields = scalar @fields; 
	
	while (scalar @records_array > $max_at_once){
		#$fields =~ s/[()]//g;
		our $mult_query = qq/INSERT INTO / . $table . " " . $fields; ### qq/ SELECT /;
		#while(my $column = shift @fields) ## Up to the last item, which then won't be followed by a comma.
		#	$mult_query .= "? AS " . $column . ", ";
		#
		#for (my $i = 0; $i < scalar @exclude_array; $i++){
		#	$mult_query .= "NULL AS " . $exclude_array[$i] . ", ";
		#
		#$mult_query =~ s/, $/ /g;
		$mult_query .= qq/ SELECT /;
		
		#$max_at_once = 80;
		our $num_records = 0;
		my @sub_records_array = @records_array[0..$max_at_once - 1];
	#	if (scalar @records_array >  $max_at_once){
	#		die "Too many records passed to this method.\n";
	#	}else{
		$num_records = scalar @records_array; #(scalar @records_array); # I already put in one line in the query from the records array.
		}
		
		#print "Number of records is $num_records\n";
		
		our $question_marks = "";
		for (my $i = 0; $i < $num_fields - 1; $i++){
			$question_marks .= "?, ";
		}
		$question_marks .= "?, ";
		#for (my $i = 0; $i < scalar @exclude_array; $i++){
		#	$question_marks .= "NULL, ";
		#
		$question_marks =~ s/, $/ /g;
		
		$mult_query .= $question_marks;
		
		our $question_string = "UNION SELECT " . $question_marks;
		# INSERT INTO Daily_table SELECT   "HET" AS Symbol, 3 AS Handle_num,46 AS Date, 36 as OPEN, 646 AS Close, 38 AS Previous_close, 63836 AS Change_last_close_to_open, 363 AS Days_high, 363 AS Days_low, 36336 AS Volume, 347 AS Change,
	#	8649367 AS Change_in_percent, 489346 as Avg_daily_volume, 3826 AS Fifty_day_avg, 3862936 AS One_yr_target, NULL AS Order_of_entry, 36238 AS Short_ratio
		#$num_records = 2;
		
		while ($num_records-- > 1){
			$mult_query .= $question_string;
		}
		#print $question_marks . "  Number of marks is $num_fields\n";
		#print "$mult_query\n";
		
		$num_records = scalar @records_array;
		#$num_records = 50;#scalar @records_array;;
		our @flat_array = ();
		
		for (my $i = 0 ; $i < $num_records; $i++){
			push(@flat_array, @{$records_array[$i]});
		}
		#print scalar @flat_array;
		
		#print "\n" . $mult_query . "\n";
		my $multiple_ins_handle = $dbhandle->prepare($mult_query);
		$multiple_ins_handle->execute(@flat_array) or die $DBI::errstr;	
	}
}

sub read_all_data{  
# Used to read all data in a table with a given entry. Arguments, after module handle, are column and data 
# (i.e. you find all entries with the given data in the column)
# Arguments: $hash_handle, $column, $data.
	if (scalar @_ != 3){
		return $e_code;
	}
	my $ref = shift(@_);
	if (set_pkg_instance($ref) == $e_code){
		return $e_code;
	}

	my $column = shift(@_);
	my $data = shift(@_);

	#Prevent SQL injection attacks
	#Here, kind of awkwardly, so that I can catch these injection attacks in my test code before determining invalid column.
	if (scrub($column) == $e_code){
		return $e_code;
	}
	#Data should be fine, the ? bind value prevents injection attacks, and I may want data that has other characters.
	
	chomp ($column);
	if (is_valid_field($column) == $e_code){
	#	print "Valid field error.\n";
		return $e_code;
	}
	
	#  Example:	SELECT Dates FROM History_data WHERE Symbol=$symbol
	my $query = qq/SELECT * FROM / . $table . ' ' . qq/ WHERE / . $column . qq/ = ?/; # Gets all the fields from the symbol row.
	my $handle = $dbhandle->prepare($query);  
	$handle->execute($data) or die $DBI::errstr;   #Execute query for the given symbol
	my $result = $handle->fetchall_arrayref([]);  #Fetch all columns
	#print $result  . "\n";
	#print join(',', @$result);
	#my $r2 = @{$result}[0];   #Decoding logic, it works, trust me. This will get the first row from the return table and return it as an array.
	#@db_fields = @{$r2};   #More decoding logic. I'm not sure how this magic works deeply, but it overall gets the rows from the 
						   #fetchall_arrayref and decodes it into an array matching the columns of the database. Matching to variables is 
						   #controlled by &decode().
	#print join(',', @$result);
	return @$result;  # Returns an array of arrays, or in other words, it gets an array of all the rows that correspond to that data.
		#&decode();  # Included at beginning of file. Sets the db_fields to global variables like $price, $date, etc.
#TODO: RETURN VALS  //Done in &decode, to global variables.
#	}

}

sub read_field{
# I'm not sure this will be a terribly useful one now that I have read_all_data.
# Basically I could do this with a regex for the field after getting the read_all_data...
# Selects one column from a record that you select by value in (possibly another) field.
# Useful to bypass the regex if you don't know what order your field is.

# Arguments: $hash_handle, $selection_column, $val_in_column, $column_to_read
# Returns: Array of strings with the value from the column.	

	if (scalar @_ != 4){
	#print "Incorrect number of args\n";
		return $e_code;
	}
	my $ref = shift(@_);
	if (set_pkg_instance($ref) == $e_code){
		return $e_code;
	}

	my $column = shift(@_);
	my $val_in_column = shift(@_);
	$val_in_column =~ s/"//g;
	my $column_to_read = shift(@_);
	
	chomp ($column);
	chomp ($column_to_read);
	chomp ($val_in_column);
	
	if ((scrub($column) == $e_code) or (is_valid_field($column) == $e_code )){
		#print "Selection column not found in this table.\n";
		return $e_code;
	}
	if (scrub($column_to_read) == $e_code or (is_valid_field($column_to_read) == $e_code)){
		#print "Column to read not found in this table.\n";
		return $e_code;
	}
	#OLD WAY#################
		#looks_like_number($field) or die "You've made an error: The field passed into read_field should be an enumerated number. $!";
		## Self explanatory: Needs enumerated type.  Old way of doing things
		#my $query = qq/SELECT * FROM History_data WHERE Symbol = ?/; #Query the database for the entire field
	#########################

	#e.g. SELECT ID FROM Stock_state WHERE Name = 2
	my $query = qq/SELECT / . $column_to_read . qq/ FROM / . $table . ' ' . qq/ WHERE / . $column . qq/ = ?/; #Query the database for the entire field
	my $handle = $dbhandle->prepare($query);  
	$handle->execute($val_in_column) or die $DBI::errstr;  #Query with symbol
	
	#Dereferencing is the same, old or new way. Probably because I'm using the fetchall_arrayref. There may be something 
	#better now that I'm just getting a single field, but I'll leave it.
	
	my $result = $handle->fetchall_arrayref([]);  #Gets the column corresponding to the field. TODO: Control.
	return @$result;
}

sub read_field_one_val{
	# Wrapper for read_field returning the first value only.

# Arguments: $hash_handle, $selection_column, $val_in_column, $column_to_read
# Returns: Array of strings with the value from the column.	

	if (scalar @_ != 4){
	#print "Incorrect number of args\n";
		return $e_code;
	}
	my $ref = shift(@_);
	my $column = shift(@_);
	my $val_in_column = shift(@_);
	my $column_to_read = shift(@_);
	my @res_array = read_field($ref, $column, $val_in_column, $column_to_read);
	return $res_array[0][0];
}

sub return_table_headers{
# A pseudo-helper function that lets you get the column headers for a the table that your handle points to. Visible outside the package.
	if (scalar @_ != 1){
		return $e_code;
	}
	my $ref = shift(@_);
	if (set_pkg_instance($ref) == $e_code){
		return $e_code;
	}
	return @valid_fields
}

#sub exists{  #Deprecated now that this is more general.
### I have removed this function from the export list.
#	my $symbol = $_[0];  #Symbol that I want to see if it's in the table. 
#	our $exists = "";  #Initialize data
#	my $check_quer = qq/SELECT ID FROM / . $table . ' ' . qq/ where / . $name_field . qq/=?/;  #Check to see if the record already exists, which I think is acceptable in this context.
#	my $check_handle = $dbhandle->prepare($check_quer);
#	$check_handle->execute($symbol) or die $DBI::errstr;
#	$exists = $check_handle->fetchrow_array();
#	if ($exists ne ""){  #Checks that the value I got back from the query isn't null, otherwise it doesn't exist.
#		return 1;		 #I don't care much for what the field *says*, per se, as that it exists.
#	}
#	return 0;
#}

sub set_multiple_fields{ # I'm too lazy to implement setting to NULL right now...
	#Inputs: $hash_handle, $select_col, $select_val, $change_col_1, $change_val_1 {, $change_col_2, $change_val_2...}
if ((((scalar @_) - 5) % 2 != 0) or (scalar @_ < 5) ){  # Use the ability to pass in ANDs/ORs, additional columns to select on, and data to select on.
	# There must be a number of arguments equal to 5 + 2*n.
	#	print "Invalid number of commands.\n";
		return $e_code;
	}
	#print join(',',@_);
	my $ref = shift(@_);
	if (set_pkg_instance($ref) == $e_code){
		#print "Entry not found in hash for this hash reference.\n";
		return $e_code;
	}
	
	my @select_val_array;
	my @where_val_array;
	my $select_column = shift(@_);
	my $select_value = shift(@_);
	my $change_column = shift(@_);
	my $change_val = shift(@_); ## With the special value of NULL
	chomp ($select_column);
	chomp ($select_value);
	$select_value =~ s/"//g;
	chomp ($change_column);
	chomp ($change_val);
########

	if ((scrub($select_column) == $e_code) or (is_valid_field($select_column) == $e_code )){
		#print "Selection column not found in this table.\n";
		return $e_code;
	}
	if (scrub($change_column) == $e_code or (is_valid_field($change_column) == $e_code)){
		#print "Column to read not found in this table.\n";
		return $e_code;
	}
	
########
	our $query = qq/UPDATE / . $table . qq/ SET / . $change_column . qq/ = /;
	our $where_query = " WHERE " . $select_column . " ";
	
	if ($change_val =~ m/NULL/i){
		$query .= "NULL ";
	}else{
		$query .= "?";
		push(@select_val_array, $change_val);
	}
	if ($select_value =~ m/NULL/i){
		$where_query .= "IS NULL";
	}else{
		$where_query .= "= ?";
		push(@where_val_array, $select_value);
	}
	
########	 Some code for variable length SQLite Queries
	
	my $sql_add_string = "";
	# e.g. for queries like UPDATE Stock_state SET ID=10 WHERE Bought_liked = 0 OR MACD = 7
	our $select_col_n;
	while (scalar @_ > 0){
		$query .= ", ";
	#	my $logical_op = shift(@_);
	#	chomp $logical_op;
	#	if ($logical_op !~ m/(^AND$|^OR$)/i )
	#		#print "Invalid logical operator.\n";
	#		return $e_code; # I only want ANDs or ORs. 
	#	
	#	$sql_add_string .= " " . $logical_op;
		$select_col_n = shift(@_);	
		chomp $select_col_n;
		if ((scrub($select_col_n) == $e_code) or (is_valid_field($select_col_n) == $e_code )){
			#print "Invalid column selected, $select_col_n.\n";
			return $e_code;
		}
		$query .= $select_col_n . " ";
		$sql_add_string .= " " . $select_col_n; # . "=?";
		my $select_val = shift(@_);
		chomp $select_val;
		if ($select_val =~ m/NULL/i){
			$query .= "IS NULL";
		}else{
			push(@select_val_array, $select_val); #Not a whole lot of validation that has to be done here. 
			$query .= "=?";
		}
	}
	
	$query .= $where_query;

	#my $erase_quer = qq/UPDATE / . $table .  qq/ SET / . $change_column ;
	#qq/=? 
	#if (!defined $change_val)
	#	$erase_quer .= "=NULL";
		#print scalar @select_val_array;
	#	my $garbage = shift(@select_val_array); #Problem here, I think it may have to do with the null value in it.
	#
	#else
	#	$erase_quer .= qq/ = ? /;
	#
	#$erase_quer .= qq/ WHERE / . $select_column;  #Sets the given field for a record to NULL.
	#if (!defined $select_value)
	#	$erase_quer .= " IS NULL";
		#print scalar @select_val_array;
	#	my $garbage = shift(@select_val_array); #Problem here, I think it may have to do with the null value in it.
	#
	#else
	#	$erase_quer .= qq/ = ? /;
	#
	#SQLStudio: UPDATE TABLE 'History_data'  \n SET Price = NULL   \n WHERE Symbol='ONNN'
	#$erase_quer .= $sql_add_string;
	#print "\n$erase_quer\n" . join(',',@select_val_array) . "\n";
	
	my $erase_handle = $dbhandle->prepare($query);
	#print "\nselarray\n" . join(',',@select_val_array) . "\n\n";
	if ((scalar @select_val_array > 0) or (scalar @where_val_array > 0)){
		$erase_handle->execute(@select_val_array, @where_val_array ) or die $DBI::errstr;
	}else{
		$erase_handle->execute() or die $DBI::errstr;	
	}
	
  #UPDATE TABLE History_data
  #SET Price = NULL 
  #WHERE Symbol='ONNN'
}

sub set_erase{  
# Erase the value in a column, selected on the values of a (potentially different) column.
# Inputs: $hash_handle, $select_column, $select_value, $change_column, $change_val {, $logical_operator, $select_column, $select_value} * n
	if ((((scalar @_) - 5) % 3 != 0) or (scalar @_ < 5) ){  # Use the ability to pass in ANDs/ORs, additional columns to select on, and data to select on.
	# There must be a number of arguments equal to 5 + 3*n.
	#	print "Invalid number of commands.\n";
		return $e_code;
	}
	#print join(',',@_);
	my $ref = shift(@_);
	if (set_pkg_instance($ref) == $e_code){
		#print "Entry not found in hash for this hash reference.\n";
		return $e_code;
	}
	my @select_val_array;
	my $select_column = shift(@_);
	my $select_value_1 = shift(@_);
	my $change_column = shift(@_);
	my $change_val = shift(@_); ## With the special value of NULL
	chomp ($select_column);
	chomp ($select_value_1);
	$select_value_1 =~ s/"//g;
	chomp ($change_column);
	if ($change_val =~ m/NULL/i){
		$change_val = undef;
	}else{
		push(@select_val_array, $change_val);
	}
	if ($select_value_1 =~ m/NULL/i){
		$select_value_1 = undef;
	}else{
		push(@select_val_array, $select_value_1);
	}
	
########	 Some code for variable length SQLite Queries
	
	my $sql_add_string = "";
	# e.g. for queries like UPDATE Stock_state SET ID=10 WHERE Bought_liked = 0 OR MACD = 7
	while (scalar @_ > 0){
		my $logical_op = shift(@_);
		chomp $logical_op;
		if ($logical_op !~ m/(^AND$|^OR$)/i ){
			#print "Invalid logical operator.\n";
			return $e_code; # I only want ANDs or ORs. 
		}
		$sql_add_string .= " " . $logical_op;
		my $select_col = shift(@_);	
		chomp $select_col;
		if ((scrub($select_col) == $e_code) or (is_valid_field($select_col) == $e_code )){
			#print "Invalid column selected, $select_col.\n";
			return $e_code;
		}
		$sql_add_string .= " " . $select_col; # . "=?";
		my $select_val = shift(@_);
		chomp $select_val;
		if ($select_val =~ m/NULL/i){
			$sql_add_string .= "IS NULL";
		}else{
			push(@select_val_array, $select_val); #Not a whole lot of validation that has to be done here. 
			$sql_add_string .= " =?";
		}
	}

########

	if ((scrub($select_column) == $e_code) or (is_valid_field($select_column) == $e_code )){
		#print "Selection column not found in this table.\n";
		return $e_code;
	}
	if (scrub($change_column) == $e_code or (is_valid_field($change_column) == $e_code)){
		#print "Column to read not found in this table.\n";
		return $e_code;
	}

	my $erase_quer = qq/UPDATE / . $table .  qq/ SET / . $change_column ;
	#qq/=? 
	if (!defined $change_val){
		$erase_quer .= "=NULL";
		#print scalar @select_val_array;
	#	my $garbage = shift(@select_val_array); #Problem here, I think it may have to do with the null value in it.
	}
	else{
		$erase_quer .= qq/ = ? /;
	}
	$erase_quer .= qq/ WHERE / . $select_column;  #Sets the given field for a record to NULL.
	if (!defined $select_value_1){
		$erase_quer .= " IS NULL";
		#print scalar @select_val_array;
	#	my $garbage = shift(@select_val_array); #Problem here, I think it may have to do with the null value in it.
	}
	else{
		$erase_quer .= qq/ = ? /;
	}
	#SQLStudio: UPDATE TABLE 'History_data'  \n SET Price = NULL   \n WHERE Symbol='ONNN'
	$erase_quer .= $sql_add_string;
	#print "\n$erase_quer\n" . join(',',@select_val_array) . "\n";
	
	my $erase_handle = $dbhandle->prepare($erase_quer);
	#print "\nselarray\n" . join(',',@select_val_array) . "\n\n";
	if (scalar @select_val_array > 0){
		$erase_handle->execute(@select_val_array ) or die $DBI::errstr;
	}else{
		$erase_handle->execute() or die $DBI::errstr;	
	}
	
  #UPDATE TABLE History_data
  #SET Price = NULL 
  #WHERE Symbol='ONNN'
}

sub read_column{
# Read all the values in a given column.
# Inputs: $handle, $column
	if (scalar @_ != 2 ){  # Use the ability to pass in ANDs/ORs, additional columns to select on, and data to select on.
	# There must be a number of arguments equal to 5 + 3*n.
		#print "Invalid number of commands.\n";
		return $e_code;
	}
	my $ref = shift(@_);
	if (set_pkg_instance($ref) == $e_code){
		#print "Entry not found in hash for this hash reference.\n";
		return $e_code;
	}
	my $select_column = shift(@_);
	chomp $select_column;
	if ((scrub($select_column) == $e_code) or (is_valid_field($select_column) == $e_code )){
		#print "Selection column not found in this table.\n";
		return $e_code;
	}
	
	my $query = qq/SELECT / . $select_column . qq/ FROM / . $table; #Query the database for the entire field
	my $handle = $dbhandle->prepare($query);  
	$handle->execute() or die $DBI::errstr;  #Query with symbol
	
	#Dereferencing is the same, old or new way. Probably because I'm using the fetchall_arrayref. There may be something 
	#better now that I'm just getting a single field, but I'll leave it.
	
	my $result = $handle->fetchall_arrayref([]);  #Gets the column corresponding to the field. TODO: Control.
	my @array = @$result;
	my @res_array;
	for (my $i = 0; $i < scalar @array; $i++){
		push(@res_array, $array[$i][0]);
	}
	return @res_array;  # Now returns a clean array. This will probably break my test code... or not. 
	
}

sub sum_col_w_args{
# Handle, $summation_column, {$sel_column, IS/ISNOT, $value.}  # I can add on additional passes later...
# For now, please be nice and only sum on numeric data... please...
  	if ((((scalar @_) - 2) % 3 != 0) or (scalar @_ < 2) ){  # Use the ability to pass in ANDs/ORs, additional columns to select on, and data to select on.
	# There must be a number of arguments equal to 2 + 3*n.
		#print "Invalid number of commands.\n";
			die "Invalid summation in sum_col_w_args1\n";
	}
	my $ref = shift(@_);
	if (set_pkg_instance($ref) == $e_code){
		#print "Entry not found in hash for this hash reference.\n";
			die "Invalid summation in sum_col_w_args2\n";
	}
	if (set_pkg_instance($ref) == -1){
		die "Invalid summation in sum_col_w_args3\n";
	}
	my $summation_column = shift(@_);
	if (scrub($summation_column) == $e_code){
		die "Invalid summation in sum_col_w_args4\n";
	}
	our $query_add = "";
	our $sel_value = "";
	if (scalar @_ != 0){
		my $sel_column = shift @_;
		if (scrub($sel_column) == $e_code){
			die "Invalid summation in sum_col_w_args5\n";
		}
		my $is_isnot = shift @_;
		$sel_value = shift @_;
		if ($is_isnot =~ s/^IS$//){
			$is_isnot = "=";
		}elsif($is_isnot =~ s/^ISNOT$//){
			$is_isnot = "!="
		}else{
			die "Invalid summation in sum_col_w_args6\n";
		}
		
		$query_add = qq/ WHERE / . $sel_column . " " . $is_isnot . " ?";
	}
	
	my $query = qq/SELECT SUM(/ . $summation_column . qq/) FROM / . $table;
	if ($query_add ne ""){
		$query .= $query_add;
	}

	my $handle = $dbhandle->prepare($query);  
	
	if ($query_add ne ""){
		$handle->execute($sel_value) or die $DBI::errstr;	
	}else{
		$handle->execute() or die $DBI::errstr;  #Query with symbol
	}
	
	my $result = $handle->fetchall_arrayref([]);  #Gets the column corresponding to the field. TODO: Control.
	my @array = @$result;
#	my @res_array;
#	for (my $i = 0; $i < scalar @array; $i++){
#		push(@res_array, $array[$i][0]);
#	}
	return $array[0][0];  # Now returns a clean array. This will probably break my test code... or not. 
}

sub search_val{
 #See if the value exists at all in a given column.
 #Inputs: $handle, $column, $value
 # Yes, I could make it variable... would that be useful?
 # Sure, why not, it's exactly the same code as delete_row except with a different SQLite query.
 # Returns an array of arrays of all cells with that value. 
  	if ((((scalar @_) - 3) % 3 != 0) or (scalar @_ < 3) ){  # Use the ability to pass in ANDs/ORs, additional columns to select on, and data to select on.
	# There must be a number of arguments equal to 5 + 3*n.
		#print "Invalid number of commands.\n";
		return $e_code;
	}
	my $ref = shift(@_);
	if (set_pkg_instance($ref) == $e_code){
		#print "Entry not found in hash for this hash reference.\n";
		return $e_code;
	}
	if (set_pkg_instance($ref) == -1){
		return "Not a valid handle.\n";
	}
	
	my $select_column = shift(@_);
	my $select_value_1 = shift(@_);
	chomp ($select_column);
	chomp ($select_value_1);
	if ($select_value_1 =~ m/NULL/i){
		$select_value_1 = undef;
	}
	
	if ((scrub($select_column) == $e_code) or (is_valid_field($select_column) == $e_code )){
		#print "Selection column not found in this table.\n";
		return $e_code;
	}
	
########	 Some code for variable length SQLite Queries
	our @select_val_array = ($select_value_1);
	
	my $sql_add_string = "";
	# e.g. for queries like UPDATE Stock_state SET ID=10 WHERE Bought_liked = 0 OR MACD = 7
	while (scalar @_ > 0){
		my $logical_op = shift(@_);
		chomp $logical_op;
		if ($logical_op !~ m/(^AND$|^OR$)/i ){
		#	print "Invalid logical operator.\n";
			return $e_code; # I only want ANDs or ORs. 
		}
		$sql_add_string .= " " . $logical_op;
		my $select_col = shift(@_);	
		chomp $select_col;
		if ((scrub($select_col) == $e_code) or (is_valid_field($select_col) == $e_code )){
			#print "Invalid column selected, $select_col.\n";
			return $e_code;
		}
		$sql_add_string .= " " . $select_col; ## . "=?";  #Only if not NULL
		my $select_val = shift(@_);
		chomp $select_val;
		if ($select_val =~ m/NULL/i){
			$select_val = undef;
			$sql_add_string .= "IS NULL";
		}
		else{
			push(@select_val_array, $select_val); #Not a whole lot of validation that has to be done here. 
			$sql_add_string .= "=?";
		}
	}
########	

	my $quer = qq/SELECT / . $select_column . qq/ FROM / . $table . qq/ WHERE / . $select_column; # . qq/ =?/;  #Sets the given field for a record to NULL.
	if (!defined $select_value_1){
		$quer .= " IS NULL";
		print scalar @select_val_array;
		my $garbage = shift(@select_val_array);
	}
	else{
		$quer .= qq/ =?/;
	}
	$quer .= $sql_add_string;
	#SQLStudio: UPDATE TABLE 'History_data'  \n SET Price = NULL   \n WHERE Symbol='ONNN'
	my $handle = $dbhandle->prepare($quer);
	if (scalar @select_val_array > 0){
		$handle->execute(@select_val_array) or die $DBI::errstr;
	}else{
		$handle->execute() or die $DBI::errstr;	
	}
	
	#my $query = qq/SELECT / . $select_column . qq/ FROM / . $table . qq/ WHERE / . $select_column . qq/ =?/; #Query the database for the entire field
	#my $handle = $dbhandle->prepare($query);  
	#$handle->execute($value) or die $DBI::errstr;  #Query with symbol
	
	#Dereferencing is the same, old or new way. Probably because I'm using the fetchall_arrayref. There may be something 
	#better now that I'm just getting a single field, but I'll leave it.
	
	my $result = $handle->fetchall_arrayref([]);  #Gets the column corresponding to the field. TODO: Control.
	return @$result; # Returns an array of arrays
}


#create_table, add_column, delete_column and some other functionality I will leave to my SQLite Studio. 
#sub add_column{
##WARNING! This will seriously break any code that is based around this module, as the arguments for write_new must have the same
# number of data to write as there are columns in the database. Use with care. 
# When testing, it must always be followed immediately by delete_column.'

#Needs to update the @valid_fields for the hash reference.

#}

#sub delete_column{
##WARNING! This will seriously break any code that is based around this module, as the arguments for write_new must have the same
# number of data to write as there are columns in the database. Use with care.
# When testing, it must always delete the column created by add_column. (Or add_column must recreate the column it deleted, but then you run into data NULL issues.)
 
#Needs to update the @valid_fields for the hash reference.
#}

sub delete_row{
# Delete a record (actually, all records) that meet the criteria. Multiple criteria, separated with AND or OR, can be input to select the row. 
# Inputs: $hash_handle, $select_column, $select_value {, $logical_operator, $select_column, $select_value} * n
	if ((((scalar @_) - 3) % 3 != 0) or (scalar @_ < 3) ){  # Use the ability to pass in ANDs/ORs, additional columns to select on, and data to select on.
	# There must be a number of arguments equal to 5 + 3*n.
	#	print "Invalid number of commands.\n";
		return $e_code;
	}
	my $ref = shift(@_);
	if (set_pkg_instance($ref) == $e_code){
		#print "Entry not found in hash for this hash reference.\n";
		return $e_code;
	}
	if (set_pkg_instance($ref) == -1){
		return "Not a valid handle.\n";
	}
	
	my $select_column = shift(@_);
	my $select_value = shift(@_);
	chomp ($select_column);
	chomp ($select_value);
	
	if ((scrub($select_column) == $e_code) or (is_valid_field($select_column) == $e_code )){
		print "Selection column not found in this table.\n";
		return $e_code;
	}
	
########	 Some code for variable length SQLite Queries
	#if ($select_value !~ m/^[0-9]/)
	#	$select_value = '\'' . $select_value . '\'';
	# # WTF?
	my @select_val_array = ( $select_value);
	
	my $sql_add_string = "";
	# e.g. for queries like UPDATE Stock_state SET ID=10 WHERE Bought_liked = 0 OR MACD = 7
	while (scalar @_ > 0){
		my $logical_op = shift(@_);
		chomp $logical_op;
		if ($logical_op !~ m/(^AND$|^OR$)/i ){
			#print "Invalid logical operator.\n";
			return $e_code; # I only want ANDs or ORs. 
		}
		$sql_add_string .= " " . $logical_op;
		my $select_col = shift(@_);	
		chomp $select_col;
		if ((scrub($select_col) == $e_code) or (is_valid_field($select_col) == $e_code )){
			#print "Invalid column selected, $select_col.\n";
			return $e_code;
		}
		$sql_add_string .= " " . $select_col . "=?";
		my $select_val = shift(@_);
		chomp $select_val;
		if ($select_value !~ m/^[0-9]/){  # The values need \' around them unless they are numbers, apparently.
			$select_value = '\'' . $select_value . '\'';
		}
		push(@select_val_array,  $select_val ); #Not a whole lot of validation that has to be done here. 
	}
########	

	my $erase_quer = qq/DELETE FROM / . $table . qq/ WHERE / . $select_column . qq/=?/;  #Sets the given field for a record to NULL.
	$erase_quer .= $sql_add_string;
	print "$erase_quer \n" . join(',',@select_val_array) . "\n";
	#SQLStudio: UPDATE TABLE 'History_data'  \n SET Price = NULL   \n WHERE Symbol='ONNN'
	my $erase_handle = $dbhandle->prepare($erase_quer);
	$erase_handle->execute(@select_val_array) or die $DBI::errstr;
}

sub number_of_records{
#Pretty straightforward, I don't think I need a lot of testing. My handle setup was copy/paste as was my number of args.
	if (scalar @_ != 1 ){  # Use the ability to pass in ANDs/ORs, additional columns to select on, and data to select on.
	# There must be a number of arguments equal to 5 + 3*n.
		#print "Invalid number of commands.\n";
		return $e_code;
	}
	my $ref = shift(@_);
	if (set_pkg_instance($ref) == $e_code){
		#print "Entry not found in hash for this hash reference.\n";
		return $e_code;
	}
	my $number_quer = qq/SELECT COUNT(*) FROM / . $table;
	my $number_handle = $dbhandle->prepare($number_quer);
	$number_handle->execute() or die $DBI::errstr;
	
	my $result = @{$number_handle->fetch()}[0];
	return $result;
}

=pod
sub append{
## Deprecated function; I'm not planning on using it right now. In any case, you can wrap the set_erase command in a perl wrapper. 
#Functionality: Should take a column that has data in it, read the data, erase the column, append the data, and then write it back.
#Alternately, this looks promising: 	UPDATE categories SET code = CONCAT(code, '_standard') WHERE id = 1;
	my $ref = $_[0];
	if (set_pkg_instance($ref) == -1){
		return "Not a valid handle.\n";
	}

	my $symbol = $_[1];
	my $record_exists = &exists($symbol);
	if ($record_exists == 0){
		die "Symbol doesn't exist and can't append. $!";
	}
	my $field = $_[2];  
	if (any{$field eq $_ } @valid_fields){  # Is a valid field
		my $append_val = $_[3];
		#  looks_like_number($field) or die "You've made an error: The field passed into append should be an enumerated number. $!";
		## Self explanatory: Needs enumerated type.
		
		my $append_query =  qq/UPDATE / . $table . qq/ SET / . $field . qq/ = CASE WHEN / . $field . qq/ IS NULL THEN  ? ELSE / . $field . qq/ ||  ? END WHERE / . $name_field . qq/ = ?/;
		my $append_handle = $dbhandle->prepare($append_query);
		$append_handle->execute($append_val, "; " . $append_val, $symbol); #Append either to a blank or add a semicolon before the next record (for easy parsing)
		##SQLite syntax: 
		# UPDATE 'History_data'
		# SET Price = 
		  # CASE WHEN Price IS NULL THEN  '123'
		  # ELSE Price || '456'
		  # END
		# WHERE Symbol = 'STM'
		#-- This may be executed on a field that is or is not NULL
	}
	else{ # I hit a column that doesn't exist.
		die "This is not a valid column in the database. Append function. $!";  #I'm going to die because this needs to be brought to my attention. 
	}
}
=cut

1;

### Good to know SQL Expressions:
=pod

SELECT * FROM History_data where Price IS NULL    -- Selects all rows where a field is NULL.

DELETE FROM History_data  -- Erase all columns.

UPDATE History_data SET Symbol='STM' WHERE Symbol IS NULL  -- Update a field. 



UPDATE 'History_data'
SET Price = 
  (CASE Price WHEN Price IS NULL THEN "123"
ELSE Price || "123231"
END)
WHERE Symbol = 'STM'


--Make this a package that works with any table and database

- Detailed Planning - Ask the average investor to show you his or her investment plan and you'll probably get sidestepped. In fact, most investors don't have a real plan.

- Technical Analysis - Regardless of any other reason to buy a stock, the charts should always be used for timing entries. Support and resistance has a huge impact on stock price movement.

- Risk management - Investors rarely use proper position sizing techniques before buying. This means they are over-exposed to risk immediately after a purchase, and often take damaging losses before they even realize what has happened. Choosing the optimum number of shares to buy in relation to personal account size provides a layer of protection every investor needs.

- Trade management - This is where the rubber meets the road. Just looking at a monthly statement once a quarter rarely works in the real world of investing. Every investor should review their portfolio at regular intervals, and use trailing stops as part of their exit strategy. It's important to know when to get in, but when it comes to making money in the stock market, knowing where to get out is worth even more.

-Columns in database for : 
	Relative strength (yearly and 3-month, update monthly at beginning of month)
	Moving Averages
	MACD
	Whether I've bought it before and liked its performance
	Industry

Bottom Line: In reality short-term trading is an efficient way to learn how to invest. Contrary to public opinion, trading is also more productive and much safer than investing - especially the way most folks invest.
From http://www.rightline.net/stock-trading-online/online-trading-investing.html

=cut
