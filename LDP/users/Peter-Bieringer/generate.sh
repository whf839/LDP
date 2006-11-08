#!/bin/sh

# 20020117/PB: review
# 20020128/PB: change PDF generation to LDP conform one, PS is still not LDP conform

# $Id$


if [ -z "$1" ]; then
	file_sgml="Linux+IPv6-HOWTO.sgml"
else
	file_sgml="$1"
fi

if ! echo "$file_sgml" | grep -q ".sgml$"; then
	echo "ERR: file is not a SGML file: $file_sgml"
	exit 1
fi

if ! head -1 "$file_sgml" |grep -q DOCTYPE ; then
	echo "ERR: file is not a SGML file: $file_sgml"
	exit 1
fi

echo "Used SGML file: $file_sgml"

file_base="`basename $file_sgml .sgml`"

file_ps="$file_base.ps"
file_pdf="$file_base.pdf"
file_txt="$file_base.txt"
file_html="$file_base.html"

file_dsl="/usr/local/share/sgml/ldp.dsl"

if [ ! -f "$file_dsl" ]; then
	echo "ERR: Missing DSL file: $file_dsl"
	exit 1
fi


if [ ! -f $file_sgml ]; then
	echo "ERR: Missing SGML file, perhaps export DocBook of LyX won't work"
	exit 1
fi

LDP_PDFPS="yes"

# run sgmlfix
if [ -e ./runsgmlfix.sh ]; then
	./runsgmlfix.sh "$file_sgml"
else
	echo "WARN: cannot execute 'runsgmlfix.sh'"
fi

# look for required binaries
for f in /usr/bin/htmldoc /usr/local/bin/ldp_print /usr/bin/nsgmls /usr/bin/jade /usr/bin/db2ps; do
	if [ ! -e $f ]; then
		echo "Missing file: $f"
		exit 1
	fi
	if [ ! -x $f ]; then
		echo "Cannot executue: $f"
		exit 1
	fi
done

validate_sgml() {
	echo "INF: Validate SGML code '$file_sgml'"
	set -x
	/usr/bin/nsgmls -s $file_sgml
	set +x
	if [ $? -gt 0 ]; then
		echo "ERR: Validation results in errors!"
		return 1
	else
		echo "INF: Validation was successfully"
	fi
}


create_html_multipage() {
	echo "INF: Create HTML multipages"
	if [ ! -d "$file_base" ]; then
		mkdir "$file_base"
	fi
	pushd "$file_base" || exit 1
	rm -f *
	set -x
	nice -n 10 /usr/bin/jade -t sgml -i html -d "/usr/local/share/sgml/ldp.dsl#html" ../$file_sgml
	local retval=$?
	set +x
	popd
	# Force
	local retval=0
	return $retval
}

create_html_singlepage() {
	echo "INF: Create HTML singlepage '$file_html'"
	set -x
	nice -n 10 /usr/bin/jade -t sgml -i html -V nochunks -d "/usr/local/share/sgml/ldp.dsl#html" $file_sgml >$file_html
	set +x
	local retval=$?
	if [ $retval -eq 0 ]; then
		echo "INF: Create HTML singlepage - done"
	else
		echo "ERR: Create HTML singlepage - an error occurs!"
	fi
	return $retval
}

create_rtf() {
	echo "INF: Create RTF file '$file_rtf'"
	set -x
	nice -n 10 /usr/bin/jade -t rtf -d /usr/local/share/sgml/ldp.dsl $file_sgml
	set +x
	local retval=$?
	if [ $retval -eq 0 ]; then
		echo "INF: Create RTF file - done"
	else
		echo "ERR: Create RTF file - an error occurs!"
	fi
	return $retval
}

create_ps() {
	echo "INF: Create PS file '$file_ps'"
	set -x
	nice -n 10 /usr/bin/db2ps --dsl /usr/local/share/sgml/ldp.dsl $file_sgml
	set +x
	local retval=$?
	if [ $retval -eq 0 ]; then
		echo "INF: Create PS file - done"
	else
		echo "ERR: Create PS file - an error occurs!"
	fi
	return $retval
}

create_pdf() {
	if [ "$LDP_PDFPS" = "yes" ]; then
		# Use LDP conform mechanism
		echo "INF: Create PDF file (LDP conform) '$file_pdf' from HTML file '$file_html'"

		if [ $file_html -ot $file_sgml ]; then
			echo "ERR: Create PDF file - needed single page HTML file '$file_html' is older than original '$file_sgml'"
			return 1
		fi
		set -x
		nice -n 10 ldp_print $file_html
		set +x
		local retval=$?
	else
		echo "INF: Create PDF file (NOT LDP conform) '$file_pdf'"
		set -x
		nice -n 10 db2pdf --dsl /usr/local/share/sgml/ldp.dsl $file_sgml
		set +x
		local retval=$?
	fi
	if [ $retval -eq 0 ]; then
		echo "INF: Create PDF file - done"
	else
		echo "ERR: Create PDF file - an error occurs!"
	fi
	return $retval
}

create_txt() {
	echo "INF: Create TXT file '$file_txt' from PS file '$file_ps'"
	[ -f $file_txt ] && rm $file_txt
	if [ -f $file_ps ]; then
		echo "INF: Create TXT file '$file_txt'"
		set -x
		nice -n 10 ps2ascii $file_ps > $file_txt
		set +x
		local retval=$?
	else
		echo "ERR: Cannot create TXT because of missing PS file"
	fi
	if [ $retval -eq 0 ]; then
		echo "INF: Create TXT file - done"
	else
		echo "ERR: Create TXT file - an error occurs!"
	fi
	return $retval
}

### Main
validate_sgml
[ $? -ne 0 ] && exit 1

create_html_multipage
if [ $? -ne 0 ]; then
	echo "ERROR : create_html_multipage was not successful"
	exit 1
fi

create_html_singlepage
if [ $? -ne 0 ]; then
	echo "ERROR : create_html_singlepage was not successful"
	exit 1
fi

create_pdf
if [ $? -ne 0 ]; then
	echo "ERROR : create_pdf was not successful"
	exit 1
fi

#create_ps
#[ $? -ne 0 ] && exit 1

#create_txt
#[ $? -ne 0 ] && exit 1

#create_rtf
#[ $? -ne 0 ] && exit 1

exit 0
