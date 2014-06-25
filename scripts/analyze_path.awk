#!/usr/bin/awk -f
# extract `obs_id' and `source name' from path
#
# LIweitiaNux <liweitianux@gmail.com>
# 2013/02/04
#
# input:
#     path that include `oi' and `source name'
#     e.g.:
#
# output:
#

# main part
{
    if (NF==1) {
        ## oi & name
        input=($1 "/")
        if (input ~ /_oi/) {
            ## PATTERN: .../$name_oi$oi/...
            idx_oi = match(input, /oi[0-9]+/) + 2;    # `2' skip the `oi'
            len_oi = RLENGTH - 2;
            oi = substr(input, idx_oi, len_oi);
            idx_name = match(input, /\/[a-zA-Z0-9.+-]+_oi/) + 1;
            len_name = RLENGTH - 4;
            name = substr(input, idx_name, len_name);
        }
        else {
            ## PATTERN: .../$name/$oi/...
            idx_oi = match(input, /\/[0-9]+\//) + 1;
            len_oi = RLENGTH - 2;
            oi = substr(input, idx_oi, len_oi);
            idx_name1 = match(input, /\/[a-zA-Z0-9_.+-]+\/[0-9]+\//);
            len_name1 = RLENGTH;
            name1 = substr(input, idx_name1, len_name1);
            idx_name = match(name1, /\/[a-zA-Z0-9_.+-]+\//) + 1;
            len_name = RLENGTH - 2;
            name = substr(name1, idx_name, len_name);
        }
        ## output
        printf("input: %s\n", input)
        printf("oi: %s\nname: %s\n", oi, name)
    }
    else {
        printf("*** WARNING: invalid input: %s\n", $0)
    }
}
# END

