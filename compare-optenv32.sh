OPT32LIBS=()
MAINPATHS=()
DIFFERS=()

if [ ! -d $PWD/runtime-optenv32 ] ; then
	echo "[!] Please run this script at the root of the ABBS tree."
	exit 1
fi

TREEDIR=$PWD

cd $PWD/runtime-optenv32

for dir in `find -maxdepth 1 -type d -printf '%P\n' | grep -- +32` ; do
	pkgname=${dir/+32/}
	echo -ne "\033[2K[${#OPT32LIBS[@]}] Finding $pkgname... \r"
	pkgpaths=($(find .. -maxdepth 3 -type d -name $pkgname -not -path '*/\.*' -printf '%P '))
	if [ "${#pkgpaths[@]}" -gt 1 ] ; then
		echo -e "\n[!] We have more than one matches for $pkgname. This should not happen."
		exit 1
	elif [ "${#pkgpaths[@]}" == "0" ] ; then
		echo -e "[!] Warning, $pkgname does not appear in the main tree."
		continue
	fi
	OPT32LIBS+=($pkgname)
	MAINPATHS+=(${pkgpaths[0]})
done

echo "There are ${#OPT32LIBS[@]} packages in optenv32."

echo "Checking for version consistency..."
TMPREPORT=$(mktemp)
TMPDIFFSET=$(mktemp)
TMPDIFFSET1=$(mktemp)
for (( i=0 ; i < ${#OPT32LIBS[@]} ; i++ )) ; do
	pkgname=${OPT32LIBS[$i]}
	echo -ne "\033[2K Checking $pkgname ...\r"
	MAINVER=
	OPT32VER=
	source "../${MAINPATHS[$i]}/spec"
	MAINVER=$VER
	source "./${pkgname}+32/spec"
	OPT32VER=$VER
	if [ "$DUMMYSRC" == "1" ] && [ "$VER" == "999" -o "$VER" == "0" ] ; then
		echo "[!] Warning, package $pkgname is a dummy package in optenv32."
		unset DUMMYSRC
		continue
	fi
	if [ "$MAINVER" != "$OPT32VER" ] ; then
		DIFFERS+=($pkgname)
		printf " \e[1;36m%-23s\e[0m| \e[1;32m%-31s\e[0m| \e[1;31m%-23s\e[0m\n" "$pkgname" "$MAINVER" "$OPT32VER" >> $TMPREPORT
		diff -u --color=always ${pkgname}+32/spec ../${MAINPATHS[$i]}/spec >> $TMPDIFFSET
		diff -u --color=never ${pkgname}+32/spec ../${MAINPATHS[$i]}/spec | sed -e "2s/\\.\\.\\/.*\\/spec/$pkgname+32\\/spec/" >> $TMPDIFFSET1
		echo "" >> $TMPDIFFSET
	fi
done

TMPFILE=$(mktemp)
echo -e "\033[47;104mComparision Summary\t\t\033[0m\n" > $TMPFILE
echo -e "- \033[1m${#OPT32LIBS[@]}\033[0m packages in total." >> $TMPFILE
echo -e "- \033[1m${#DIFFERS[@]}\033[0m of them has inconsistent versions across main tree and optenv32." >> $TMPFILE

cat >> $TMPFILE << EOF

Version inconsistencies:

 Package Name		| Version in the main tree	 | Version in optenv32	  
------------------------|--------------------------------|------------------------
EOF
cat $TMPREPORT >> $TMPFILE
cat >> $TMPFILE << EOF

All ${#DIFFERS[@]} diffs:

EOF

trap "rm -f $TMPFILE $TMPDIFFSET $TMPREPORT $TMPDIFFSET1" EXIT

cat $TMPDIFFSET >> $TMPFILE

CHOICE=r
while [ "$CHOICE" == "r" ] ; do

less -R -P "Use arrow keys to navigate, [q] to quit when done." $TMPFILE
echo "You can review it again by answering 'r'."
read -p "Or, choose whether to sync the versions now [Y/n/r]: " ANS
[ ! "$ANS" ] && ANS=y
case "$ANS" in
	Y|y)
		echo "Applying patches..."
		patch -p0 -d $TREEDIR/runtime-optenv32 < $TMPDIFFSET1
		echo "Removing RELs..."
		for i in ${DIFFERS[@]} ; do
			sed -i -e '/REL=/d' $i+32/spec
		done
		echo "Done!"
		CHOICE=
		;;
	R|r)
		;;
	*)
		echo "Doing nothing."
		CHOICE=
		;;
esac
done

exit 0
