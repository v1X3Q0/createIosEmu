# createIosEmu
usage:
```./createVm.sh $PATH_OF_IPSW $IOS_VERSION```
example:

<pre><code>
mkdir ios_13_3
cd ios_13_3
cp ../*.sh .
cp ../bash.plist .
sudo su
exit
./createVm.sh ~/Projects/ipsw/iPhone_5.5_13.3_17C54_Restore.ipsw IOS_13_3
./startup.sh
</code></pre>