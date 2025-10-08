* * * * * * * * * * * * * * * * * * * * * * * * * * * 
* Author: Ania Zylbersztejn, ania.zylbersztejn@ucl.ac.uk
* Code list: neuro_zylbersztejn_v1
* * * * * * * * * * * * * * * * * * * * * * * * * * * 

* set-up ------------------------------------------------------------------

* Clear workspace
clear all

* Other housekeeping
capture log close


* load data --------------------------------------------------

odbc load, exec(`"SELECT TOP 100000 * from dbo.FILE0184861_HES_APC_2019"') connectionstring("[omitted]") 

foreach var of varlist _all { //change varnames to lowercase
	capture rename `var', lower
	}

* save only relevant variables
keep tokenid startage diag* opertn* 

* generate a variable with all diagnoses
	
gen diag_concat=diag_01 + "."+diag_02 + "." + diag_03 + "."+ diag_04 + "."+ diag_05 + "."+ diag_06 + "."+ diag_07 + "."+ diag_08 + "."+ diag_09 + "."+ diag_10 + "."+ diag_11 + "."+ diag_12 + "."+ diag_13 + "."+ diag_14 + "."+ diag_15 + "."+ diag_16 + "."+ diag_17 + "."+ diag_18 + "."+  diag_19 + "."+ diag_20

* generate a variable with all procedures

gen opertn_concat=opertn_01 + "."+opertn_02 + "." + opertn_03 + "."+ opertn_04 + "."+ opertn_05 + "."+ opertn_06 + "."+ opertn_07 + "."+ opertn_08 + "."+ opertn_09 + "."+ opertn_10 + "."+ opertn_11 + "."+ opertn_12 + "."+ opertn_13 + "."+ opertn_14 + "."+ opertn_15 + "."+ opertn_16 + "."+ opertn_17 + "."+ opertn_18 + "."+  opertn_19 + "."+ opertn_20


* flag individuals with any relevant diagnostic or procedure code --------------------------------------------------

* this code uses local macros therefore all code until the end of this section needs to be run in one go

local neuro_diag_any "A066 A17 A170 A171 A178 A179 A203 A321 A390 A50 A500 A501 A502 A503 A504 A505 A506 A507 A509 A521 A522 A523 A800 A801 A802 A803 A809 A810 A811 A812 A818 A82 A820 A821 A829 A83 A830 A831 A832 A833 A834 A835 A836 A838 A839 A84 A840 A841 A848 A849 A85 A850 A851 A852 A858 A86 B003 B004 B010 B011 B020 B021 B050 B051 B060 B261 B262 B375 B384 B431 B451 B500 B582 B690 B900 B91 B941 C70 C700 C701 C709 C71 C710 C711 C712 C713 C714 C715 C716 C717 C718 C719 C72 C720 C721 C722 C723 C724 C725 C728 C729 D32 D320 D321 D329 D33 D330 D331 D332 D333 D334 D337 D339 D43 D430 D431 D432 D433 D434 D437 D439 D821 E00 E000 E001 E002 E009 E702 E703 E708 E709 E71 E710 E711 E712 E713 E72 E720 E721 E722 E723 E724 E725 E728 E729 E74 E740 E741 E742 E743 E744 E748 E749 E75 E750 E751 E752 E753 E754 E755 E756 E76 E760 E761 E762 E763 E768 E769 E77 E770 E771 E778 E779 E791 E798 E799 E830 E851 E888 E889 F70 F71 F72 F73 F78 F79 F80 F800 F801 F802 F803 F808 F809 F81 F810 F811 F812 F813 F818 F819 F82 F83 F84 F840 F841 F842 F843 F844 F845 F848 F849 F88 F89 F90 F900 F901 F908 F909 F91 F910 F911 F912 F913 F918 F919 F92 F920 F928 F929 F951 F952 F958 F959 F984 G00 G000 G001 G002 G003 G008 G009 G01 G021 G028 G03 G030 G031 G032 G038 G039 G04 G040 G041 G042 G048 G049 G05 G050 G051 G052 G058 G06 G060 G061 G062 G07 G08 G09 G10 G11 G110 G111 G112 G113 G114 G118 G119 G12 G120 G121 G122 G128 G129 G13 G130 G131 G132 G138 G14 G20 G21 G210 G211 G212 G213 G214 G218 G219 G22 G23 G230 G231 G232 G233 G238 G239 G240 G241 G242 G243 G244 G248 G249 G252 G254 G255 G258 G259 G26 G31 G310 G311 G312 G318 G319 G32 G320 G328 G35 G36 G360 G361 G368 G369 G37 G370 G371 G372 G373 G374 G375 G378 G379 G40 G400 G401 G402 G403 G404 G405 G406 G407 G408 G409 G41 G410 G411 G412 G418 G419 G46 G460 G461 G462 G463 G464 G465 G466 G467 G468 G60 G600 G601 G602 G603 G608 G609 G611 G618 G619 G62 G620 G621 G622 G628 G629 G63 G630 G631 G632 G633 G634 G635 G636 G638 G70 G700 G701 G702 G708 G709 G71 G710 G711 G712 G713 G718 G719 G723 G724 G728 G729 G73 G730 G731 G732 G733 G734 G735 G736 G737 G80 G800 G801 G802 G803 G804 G808 G809 G81 G810 G811 G819 G82 G820 G821 G822 G823 G824 G825 G83 G830 G831 G832 G833 G834 G835 G838 G839 G900 G901 G904 G908 G909 G91 G910 G911 G912 G913 G918 G919 G92 G930 G931 G934 G935 G936 G937 G938 G939 G94 G940 G941 G942 G948 G95 G950 G951 G952 G958 G959 G972 G99 G990 G991 G992 G998 H185 H312 H351 H360 H368 H472 H473 H474 H475 H476 H477 H480 H488 H540 H541 H542 H545 H549 H903 H904 H905 H906 H907 H908 H913 I60 I600 I601 I602 I603 I604 I605 I606 I607 I608 I609 I61 I610 I611 I612 I613 I614 I615 I616 I618 I619 I63 I630 I631 I632 I633 I634 I635 I636 I638 I639 I64 I67 I670 I671 I672 I673 I674 I675 I676 I677 I678 I679 I680 I69 I690 I691 I692 I693 I694 I698 I780 M896 P044 P100 P101 P102 P103 P104 P108 P109 P210 P350 P351 P352 P358 P359 P370 P371 P522 P523 P524 P525 P526 P528 P529 P57 P570 P578 P579 P90 P910 P911 P912 P915 P916 P917 P961 Q00 Q000 Q001 Q002 Q01 Q010 Q011 Q012 Q018 Q019 Q02 Q03 Q030 Q031 Q038 Q039 Q04 Q040 Q041 Q042 Q043 Q044 Q045 Q046 Q048 Q049 Q05 Q050 Q051 Q052 Q053 Q054 Q055 Q056 Q057 Q058 Q059 Q060 Q061 Q062 Q063 Q064 Q068 Q069 Q078 Q079 Q134 Q138 Q139 Q150 Q750 Q85 Q850 Q851 Q858 Q859 Q860 Q861 Q862 Q868 Q870 Q871 Q872 Q873 Q875 Q878 Q899 Q90 Q900 Q901 Q902 Q909 Q91 Q910 Q911 Q912 Q913 Q914 Q915 Q916 Q917 Q92 Q920 Q921 Q922 Q923 Q924 Q925 Q926 Q927 Q928 Q929 Q93 Q930 Q931 Q932 Q933 Q934 Q935 Q936 Q937 Q938 Q939 Q970 Q971 Q972 Q978 Q979 Q980 Q981 Q982 Q983 Q984 Q985 Q986 Q987 Q988 Q989 Q992 Q998 Q999 T850 Y460 Y461 Y462 Y463 Y464 Y465 Y466 Y467 Y468 Z453 Z461 Z962 Z974 Z982"

local neuro_diag_28days "A872 B007 B018 B069"

local neuro_opertn_any "A12 A13 A14 A16 D05 D13 D16 D24 D241 D242 D243 D244 D246 D248 D249"

local neuro_opertn_28days "X501 X502 X503 X504 X505 X511 X512"


capture drop neuro_flag
gen neuro_flag=.

qui foreach k of local neuro_diag_any {
           replace neuro_flag=1 if strpos(diag_concat,"`k'")>0 
           }

qui foreach k of local neuro_diag_28days {
           replace neuro_flag=1 if strpos(diag_concat,"`k'")>0 & startage>7000 & startage<7004
           }

qui foreach k of local neuro_opertn_any {
           replace neuro_flag=1 if strpos(opertn_concat,"`k'")>0 
           }

qui foreach k of local neuro_opertn_28days {
           replace neuro_flag=1 if strpos(opertn_concat,"`k'")>0 & startage>7000 & startage<7004
           }

* now clean and deduplicate the data =======================================

* add labels
keep if neuro_flag==1

* save only tokenid
keep tokenid
duplicates drop * , force

gen neuro=1

* save a list of IDs with
save "xxxx.dta", replace


