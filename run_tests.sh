for t in `ls test`
do
    lua test/${t}/run.lua
    if [ $? -eq 0 ] 
    then 
        echo "test $t ok"
    else
        echo "test $t failed"
    fi
done 

