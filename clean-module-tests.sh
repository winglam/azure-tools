# Meant to run inside azure-tools/module-summarylistgen

# remove PUTs
for f in $(grep "\\["  *.csv ); do # ]
    fi=$(echo $f | cut -d':' -f1);
    l=$(echo $f | cut -d':' -f2- | sed 's/\./\\./g' | sed 's/\[/\\[/g'  | sed 's/\]/\\]/g');
    sed -i "/^${l}$/d" $fi;
done

# removes tests with no test method name
for f in $(grep  \\.$ *.csv ); do
    fi=$(echo $f | cut -d':' -f1);
    l=$(echo $f | cut -d':' -f2- | sed 's/\./\\./g');
    sed -i "/^${l}$/d" $fi;
done

for f in $(grep "\\]"  *.csv ); do fi=$(echo $f | cut -d':' -f1); l=$(echo $f | cut -d':' -f2- | sed 's/\./\\./g' | sed 's/\[/\\[/g'  | sed 's/\]/\\]/g'); sed -i "/^${l}$/d" $fi; done

for f in $(grep -v \\. *.csv ); do fi=$(echo $f | cut -d':' -f1); l=$(echo $f | cut -d':' -f2- | sed 's/\./\\./g' | sed 's/\[/\\[/g'  | sed 's/\]/\\]/g'); sed -i "/^${l}$/d" $fi; done
