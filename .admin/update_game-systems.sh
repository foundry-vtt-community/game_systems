#!/bin/bash

# From https://stackoverflow.com/questions/296536/how-to-urlencode-data-for-curl-command

rawurlencode() {
  local string="${1}"
  local strlen=${#string}
  local encoded=""
  local pos c o

  for (( pos=0 ; pos<strlen ; pos++ )); do
     c=${string:$pos:1}
     case "$c" in
        [-_.~a-zA-Z0-9] ) o="${c}" ;;
        * )               printf -v o '%%%02x' "'$c"
     esac
     encoded+="${o}"
  done
  echo "${encoded}"    # You can either set a return variable (FASTER)
  REPLY="${encoded}"   #+or echo the result (EASIER)... or both... :p
}

# Clear game_system file
echo > game_system.md
topdir=$(pwd)

# Remove any csplit files from a previously aborted job
rm -f csplit-sections-*

# Split the community game systems by sections
csplit ../wiki.wiki/Community-Game-Systems.md '/^# /' '{*}' --prefix csplit-sections- > /dev/null

for section in csplit-sections-* ; do
	cd $topdir
	# Get first line and Trim leading/trailing whitespace
	section_name=$(head -n 1 $section | cut -d' ' -f 2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
	if [[ "$section_name" != "" && "$section_name" != "Appendix" ]]; then
		echo "Found section : $section_name"
		# Split the section into modules
		csplit $section '/^## /' '{*}' --prefix csplit-modules- > /dev/null
		for module in csplit-modules-* ; do
			name=$(head -n 1 $module | cut -d' ' -f 2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
			if [[ "$name" == "$section_name" ]] ; then
				cat $module >> game_system.md
				continue
			fi
			if [[ "$name" == "(Game System Name)" ]] ; then continue; fi
			url=$(grep 'https://git' $module | cut -d[ -f 2 | cut -d] -f 1)
			# Get first line of the description
			description=$(cat $module | grep -A 1 '### Description' | tail -n 1)
			echo "Found module : $name"
			if [[ "$description" != "" || "$url" != "" ]] ; then
				echo "   Description : $description"
				mkdir -p "$section_name"
				dir=$name
				if [[ "$url" != "" ]] ; then
					echo "   URL : $url"
					dir=$(basename "$url")
					if [[ -d "$section_name/$dir" ]] ; then
						git submodule update --remote "$section_name/$dir"
					else
						git submodule add $url "$section_name/$dir"
					fi
				fi
				mv $module "${section_name}/${dir}.md"
				git add "${section_name}/${dir}.md"
				link="$(rawurlencode "${section_name}")/$(rawurlencode "${dir}").md"
				echo "## [$name]($link)" >> game_system.md
				echo $description >> game_system.md
				echo "" >> game_system.md
			else
				echo "Skipping this one"
			fi
			echo ""
		done
		rm -f csplit-modules-*
	fi
done
rm -f csplit-sections-*

cat header.md game_system.md > README.md
rm game_system.md
