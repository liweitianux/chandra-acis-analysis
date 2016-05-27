ln -sf $XANBIN/lib/libcpgplot*.a ./libcpgplot.a
ln -sf $XANBIN/lib/libpgplot*.a ./libpgplot.a
echo LIB ./ >pgplot_path.txt
echo INC $XANBIN/include >>pgplot_path.txt

chmod a+x *.py
