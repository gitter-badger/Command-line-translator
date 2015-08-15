#!/usr/bin/env perl
use strict; # ограничить применение небезопасных конструкций
use warnings; # выводить подробные предупреждения компилятора
use diagnostics; # выводить подробную диагностику ошибок
use Getopt::Std;
use File::Basename;
use LWP::UserAgent;
#libjson-perl
use JSON;
use HTML::Entities;
use utf8;
use v5.16;
#use Text::Unidecode;
package main;
#binmode(STDOUT, ":utf8");

# adjust to taste
my $FIRST_LANG='ru';		#target language for request in LATIN_LANG		NOT in A-z latin alphabet
my $LATIN_LANG='en';		#target for all not A-z latin requests			A-z latin alphabet will be detected!
my $TERMINAL_C="WOB";		#Your terminal - white on black:WOB, black on white:BOW, anything other:O

my $TRANSLIT_WORDS_MAX = 10;
my @PROXY ;#= ('http','http://127.0.0.1:4446');

my $USERAGENT = 'Mozilla/5.0 (Windows NT 5.1; rv:5.0.1) Gecko/20100101 Firefox/5.0.1';


#Solved problems:
#  gppgle JSON converting problem ,,. Solved by hands.
#  google JSON article=white space - problem. Solved by hands.

my $name = basename($0);
my %LANGS = (
    'af' => 'Afrikaans',
    'sq' => 'Albanian',
    'am' => 'Amharic',
    'ar' => 'Arabic',
    'hy' => 'Armenian',
    'az' => 'Azerbaijani',
    'eu' => 'Basque',
    'be' => 'Belarusian',
    'bn' => 'Bengali',
    'bg' => 'Bulgarian',
    'ca' => 'Catalan',
    'zh-CN' => 'Chinese (Simplified)',
    'zh' => 'Chinese',
    'hr' => 'Croatian',
    'cs' => 'Czech',
    'da' => 'Danish',
    'nl' => 'Dutch',
    'en' => 'English',
    'eo' => 'Esperanto',
    'et' => 'Estonian',
    'fo' => 'Faroese',
    'tl' => 'Filipino',
    'fi' => 'Finnish',
    'fr' => 'French',
    'gl' => 'Galician',
    'ka' => 'Georgian',
    'de' => 'German',
    'el' => 'Greek',
    'gu' => 'Gujarati',
    'ht' => 'Haitian Creole',
    'iw' => 'Hebrew',
    'hi' => 'Hindi',
    'hu' => 'Hungarian',
    'is' => 'Icelandic',
    'id' => 'Indonesian',
    'ga' => 'Irish',
    'it' => 'Italian',
    'ja' => 'Japanese',
    'kn' => 'Kannada',
    'ko' => 'Korean',
    'lo' => 'Laothian',
    'la' => 'Latin',
    'lv' => 'Latvian',
    'lt' => 'Lithuanian',
    'mk' => 'Macedonian',
    'ms' => 'Malay',
    'mt' => 'Maltese',
    'no' => 'Norwegian',
    'fa' => 'Persian',
    'pl' => 'Polish',
    'pt' => 'Portuguese',
    'ro' => 'Romanian',
    'ru' => 'Russian',
    'sr' => 'Serbian',
    'sk' => 'Slovak',
    'sl' => 'Slovenian',
    'es' => 'Spanish',
    'sw' => 'Swahili',
    'sv' => 'Swedish',
    'ta' => 'Tamil',
    'te' => 'Telugu',
    'th' => 'Thai',
    'tr' => 'Turkish',
    'uk' => 'Ukrainian',
    'ur' => 'Urdu',
    'vi' => 'Vietnamese',
    'cy' => 'Welsh',
    'yi' => 'Yiddish'
);

$SIG{INT} = \&sig_handler;
sub sig_handler { #Ctrl+C detection.
   print "Exit signal detected. Deleting cache files.\n";
   exit;
}

# Message about this program and how to use it
sub usage()
{
    print STDERR << "EOF";
$name [-S] [-l] [-h] [-p] [-s language_2_chars] [-t language_2_chars]
if text is LATIN_LANG, then target language is FIRST_LANG
otherwise, target language is LATIN_LANG
-S Enable sound for one word
//-p Prompt mode
-s lang Set source language
-t lang Set target language
-l List of languages
You can force the language with environment varibles by command:
export TLSOURCE=en TLTARGET=ru
but better configure "FIRST_LANG" and "LATIN_LANG" in script for auto detection of direction by the first character!
You neeed UTF-8 support for required languages.
EOF
    exit 0;
}

sub google($$$){#$_[0] - ua    $_[1] - url   #$_[2] - request
    my $req = HTTP::Request->new(POST => $_[1]);
    $req->content("text=$_[2]");
    my $response;
    $response = $_[0]->request($req);
    $response = $_[0]->request($req) if (! $response->is_success); #resent
    return $response;
}

sub testing($){
    my $g_array = $_[0];
    if(ref($g_array) eq 'ARRAY'){
	for (my $row = 0; $row < @{$g_array}; $row++){
	    if(ref($g_array->[$row]) eq 'ARRAY'){
		for (my $col = 0; $col < @{$g_array->[$row]}; $col++) {
		    if(ref($g_array->[$row][$col]) eq 'ARRAY'){
			for (my $i = 0; $i < @{$g_array->[$row][$col]}; $i++) {
			    if(ref($g_array->[$row][$col][$i]) eq 'ARRAY'){
				for (my $j = 0; $j < @{$g_array->[$row][$col][$i]}; $j++) {
				    if(ref($g_array->[$row][$col][$i][$j]) eq 'ARRAY'){
					for (my $s = 0; $s < @{$g_array->[$row][$col][$i][$j]}; $s++) {
					    print "a5:$row,$col,$i,$j,$s:".$g_array->[$row][$col][$i][$j][$s]."\n";
					}
				    }else{print "e4:$row,$col,$i,$j:".$g_array->[$row][$col][$i][$j]."\n";}
				}
			    }else{ print "e3:$row,$col,$i:".$g_array->[$row][$col][$i]."\n";}
			}
		    }else{ print "e2:$row,$col:".$g_array->[$row][$col]."\n";}
		}
	    }else{ print "e1:$row:".$g_array->[$row]."\n";}
	}
    }
}

my $C_RED;            #highlight
my $C_YELLOW;         #highlight
my $C_GRAY;           #language detected
my $C_CYAN_RAW;       #forms
my $C_GRAY_RED_RAW;   #phrases
my $C_DARK_BLUE_RAW;  #link for dictionary
my $C_BLUE_RAW;       #dictionary and vform1, suggestions
my $C_BRIGHT_RAW;     #phrases, examples main part, vform2
my $C_GREEN;          #t_result
if ($TERMINAL_C eq "WOB" ){
    $C_RED=`tput bold`.`tput setaf 1`;
    $C_YELLOW=`tput bold`.`tput setaf 3`;
    $C_GRAY="`tput setaf 7`";
    $C_CYAN_RAW="\033[1;36m";
    $C_GRAY_RED_RAW="\033[1;35m";
    $C_DARK_BLUE_RAW="\033[34m";
    $C_BLUE_RAW="\033[1;34m";
    $C_BRIGHT_RAW="\033[1;37m";
    $C_GREEN="\033[1;32m";
}elsif( $TERMINAL_C eq "BOW" ){
    $C_RED="`tput bold``tput setaf 1`";
    $C_YELLOW="`tput setaf 3`";
    $C_GRAY="`tput bold``tput setaf 5`";
    $C_CYAN_RAW="\033[1;36m";
    $C_GRAY_RED_RAW="\033[1;35m";
    $C_DARK_BLUE_RAW="`tput setaf 7`";
    $C_BLUE_RAW="\033[1;34m";
    $C_BRIGHT_RAW="`tput bold`";
    $C_GREEN="`tput bold`";
}else{ #universal
    $C_RED="`tput setaf 1`";
    $C_YELLOW="`tput bold`";
    $C_GRAY="";
    $C_CYAN_RAW="";
    $C_GRAY_RED_RAW="";
    $C_DARK_BLUE_RAW="";
    $C_BLUE_RAW="";
    $C_BRIGHT_RAW="`tput bold`";
    $C_GREEN="`tput bold`";
}
my $C_NORMAL="`tput sgr0`";
my $C_NORMAL_RAW="\033[0m";

my %opt =();
getopts( ":hlpSs:t:", \%opt ) or print "Usage: $name: [-S] [-h] [-l] [-p] [-s language_2_chars] [-t language_2_chars]\n" and exit;

my $source;
my $target;
my $sound = 0;
#my $PROMPT_MODE_ACTIVATED;
my $TLSOURCE;
my $TLTARGET;
my $request;

#Switch options
usage() if defined $opt{h};
$sound = 1 if defined $opt{S};
#if ($opt{p}){
#	print STDERR "Prompt mode activated";
#	$PROMPT_MODE_ACTIVATED=1;
#}
if (defined $opt{l}){
    foreach my $value (sort { $LANGS{$a} cmp $LANGS{$b} } keys %LANGS){
	print $value."\t".$LANGS{$value}."\n";}
    exit;
}
if (defined $opt{s}){
    $TLSOURCE = $opt{s} if defined $LANGS{$opt{s}};
#    print $TLSOURCE;
}
if ($opt{t}){
    $TLSOURCE = $opt{t} if defined $LANGS{$opt{t}};    
}
$request= join(" ", @ARGV);
$request =~ s/^\s+|\s+$//g;     #trim both sides
exit 1 if ! length $request;

my $w_count = scalar(split(/\s+/,$request));

#Language detection by the first character (very simple)
foreach my $ch (map {split //} split('\s',(substr $request,0,10))){
#    print ord $ch, "\n"; #65 - 122 = Latin
    if (ord $ch > 65 && ord $ch < 122 )
    {	    $source = $LATIN_LANG;   $target = $FIRST_LANG;    last;
    }else{  $source = 'auto';        $target = $LATIN_LANG;   } # For any other language
}
#print 'A'.$request."A\n";

my $ua = LWP::UserAgent->new; #Internet connection main object, we will clone it
$ua->agent($USERAGENT);
$ua->proxy([$PROXY[0]], $PROXY[1]) if @PROXY;
     
my $url="https://translate.google.com/translate_a/single?client=t&sl=$source&tl=$target&hl=en&dt=bd&dt=ex&dt=ld&dt=md&dt=qca&dt=rw&dt=rm&dt=ss&dt=t&dt=at&ie=UTF-8&oe=UTF-8";
#my $req = HTTP::Request->new(POST => $url);
#$req->content("text=$request");
#my $response;
#$response = $ua->request($req);
#$response = $ua->request($req) if (! $response->is_success); #resent
my $response = &google($ua->clone, $url, $request) ; #$_[0] - ua    $_[1] - url   #$_[2] - request

my $g_array;
if ($response->is_success) { #to array
    #print $response->decoded_content;
#    if ($response->isa('HTTP::Response::JSON')) {
    #my $json = $response->json_content; #decoded
    my $js = $response->decoded_content;
    $js =~ s/,,/,"",/g;
    $js =~ s/,,/,"",/g;
    $js =~ s/\[,/\["",/g;
    $js =~ s/,\]/,""\]/g;
    print $js."\n";
    #my $g_array = decode_json($js);
    #my @objs = JSON->new->incr_parse ($js);
    $g_array =  JSON->new->decode($js);
#    my $pp = JSON->new->pretty->encode( $g_array ); # pretty-printing
#    print $pp;
    
#    &testing($g_array);

}
else {
    print $response->status_line, "\n"; exit 1;
}

my $rsum; # translation
my $translit; # translit
my @suggest; #google suggestions. appears sometimes.(options_for_one_word)
my $detected_language;
my $error1; #error with highlight
my $error2; #correct version
if(ref($g_array) eq 'ARRAY'){
    #translation
    if(length $request < 1000){ # if <1000 we will fix english article problem if >1000 leave it be
	if(ref($g_array->[5]) eq 'ARRAY'){
	    for (my $col = 0; $col < @{$g_array->[5]}; $col++) {
		if($g_array->[5][$col][2][0][0]){
		    my $t = $g_array->[5][$col][2][0][0];
		    $rsum .= $t." ";
		}
	    }
	}
    }else{
	if(ref($g_array->[0]) eq 'ARRAY'){
	    for (my $col = 0; $col < @{$g_array->[0]}; $col++) {
		if($g_array->[0][$col][0]){
		    my $t = $g_array->[0][$col][0];
		    $rsum .= $t;
		}
	    }
	}
    }
    #translit
    if($w_count <= $TRANSLIT_WORDS_MAX){
	if($g_array->[0][1][3]){
	    $translit = $g_array->[0][1][3];
	}
    }
    #suggestions
    if(ref($g_array->[5][0][2]) eq 'ARRAY'){	
	for (my $col = 0; $col < @{$g_array->[5][0][2]}; $col++) {
	    if($g_array->[5][0][2][$col][0]){
		@suggest=(@suggest,$g_array->[5][0][2][$col][0]);#add element
	    }
	}
    }
    #language detections
    if($g_array->[8][0][0]){
	$detected_language = $g_array->[8][0][0];
    }else{ print "strange error in google json1";}
    #error detection
    if(ref($g_array->[7]) eq 'ARRAY'){	
	if($g_array->[7][0] && $g_array->[7][1]){
	    $error1 = decode_entities($g_array->[7][0]); #decode html character entities
	    $error2 = $g_array->[7][1];
	}else{ print "strange error in google json2";}
	
	#Highlight - error checking
	if($w_count <= 2){
	    my @request = split //,$request;
	    my @right = split //, $error2;
	    my @fixed = @right;#working array
	    my $count = 0;    #insertions
	    my $save = -1;
	    my $n = scalar @right;
	    my $pos;          #index + insertions
	    for(my $i = 0; $i < $n; $i++){ #diff strings and highlight insertion
		if($request[$i] && ($right[$i] ne $request[$i])){
		    if ($save+1 != $i){		
			$pos = $count+$i;
			@fixed = (@fixed[0..$pos-1], $C_RED ,@fixed[$pos..$n+$count-1]);
			$count++;
		    }
		    $save=$i;#error save position
		}elsif($save+1 == $i){
		    $pos = $count+$i;
		    @fixed = (@fixed[0..$pos-1], $C_YELLOW ,@fixed[$pos..$n+$count-1]);
		    $count++;
		}
	    }
	    @fixed = (@fixed, $C_NORMAL_RAW);
	    $error1 = join '', @fixed;
	}else{
	    $error1 =~ s|<b><i>|$C_YELLOW|g;
	    $error1 =~ s|</i></b>|$C_NORMAL_RAW|g;
	}
    }
}else{ print $response,"\n"; exit 1;}
$rsum =~ s/\s+,/,/g; #asd , asd
$rsum =~ s/\s+\./\./g; #asdas .
$rsum =~ s/\s+\?/?/g; #asdas ?
$rsum =~ s/\s+\!/!/g; #asdas !
$rsum =~ s/\s+\"\s+/ /g; #students’ are either   =  студенты " либо



#echo
print $C_GREEN.$rsum.$C_NORMAL_RAW,"\n"; #echo resul
if($error1){
    print $error1,"\n"; #echo error
    exit 0;#enough
}
if(scalar @suggest > 1){ #echo options or suggestions
    print $C_BLUE_RAW."Options:".$C_NORMAL_RAW,"\n";
    print $_,"\n" foreach @suggest 
};
