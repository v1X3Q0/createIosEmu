
VM_NAMTE=$1
IOS_VER=$2
unzip ${VM_NAMTE}

wget https://github.com/alephsecurity/xnu-qemu-arm64-tools/archive/master.zip
unzip master.zip
mv xnu-qemu-arm64-tools-master xnu-qemu-arm64-tools
rm -rf master.zip

python3 xnu-qemu-arm64-tools/bootstrap_scripts/asn1kerneldecode.py kernelcache.release.n66 kernelcache.release.n66.asn1decoded
python3 xnu-qemu-arm64-tools/bootstrap_scripts/decompress_lzss.py kernelcache.release.n66.asn1decoded kernelcache.release.n66.out
python3 xnu-qemu-arm64-tools/bootstrap_scripts/asn1dtredecode.py Firmware/all_flash/DeviceTree.n66ap.im4p Firmware/all_flash/DeviceTree.n66ap.im4p.out

fileST=()
fileNM=()
ramFS=()
ipswFS=()

for filename in ./*.dmg; do
    myfilesize=$(wc -c "${filename}" | awk '{print $1}')
    if [ ${#fileST[@]} -eq 0 ]
    then
        fileST+=("$myfilesize")
        fileNM+=("$filename")        
    elif [ $myfilesize -ge ${fileST[ ${#fileST[@]} - 1 ]} ]
    then
        fileST+=("$myfilesize")
        fileNM+=("$filename")        
    elif [ $myfilesize -le ${fileST[ 0 ]} ]
    then
        fileST=("$myfilesize" ${fileST[@]})
        fileNM=("$filename" ${fileNM[@]})
    else
        ramFS=${filename}
    fi
done

if [ ${#fileST[@]} -eq 3 ]
then
    ramFS=${fileNM[ ${#fileNM[@]} - 2 ]}
fi

ipswFS=${fileNM[ ${#fileNM[@]} - 1 ]}

# cause I don't have resize yet:
# python3 xnu-qemu-arm64-tools/bootstrap_scripts/asn1rdskdecode.py ${ramFS} ${ramFS}.out
cp ~/Projects/ipsw/ramfsExt/${ramFS}.out ${ramFS}.out

mntVolRam=ramFSMnt
mntVolFS=ipswFSMnt
# PeaceXXXXXX.arm64UpdateRamDisk
mkdir ramFSMnt
echo "darling-dmg ${ramFS} ramFSMnt"
darling-dmg ${ramFS} ramFSMnt
# not peace
mkdir ipswFSMnt
darling-dmg ${ipswFS} ipswFSMnt

sudo mkdir -p ${mntVolRam}/System/Library/Caches/com.apple.dyld/
sudo cp ${mntVolFS}/System/Library/Caches/com.apple.dyld/dyld_shared_cache_arm64 ${mntVolRam}/System/Library/Caches/com.apple.dyld/
sudo chown root ${mntVolRam}/System/Library/Caches/com.apple.dyld/dyld_shared_cache_arm64

wget https://github.com/jakeajames/rootlessJB/archive/master.zip
unzip master.zip
mv rootlessJB-master rootlessJB
rm -rf master.zip

cd rootlessJB/rootlessJB/bootstrap/tars/
tar xvf iosbinpack.tar
sudo cp -R iosbinpack64 ${mntVolRam}
cd -

sudo rm ${mntVolRam}/System/Library/LaunchDaemons/*
sudo cp bash.plist ${mntVolRam}/System/Library/LaunchDaemons/bash.plist

touch ./tchashes
for filename in $(find ${mntVolRam}/iosbinpack64 -type f); do jtool --sig --ent $filename 2>/dev/null; done | grep CDHash | cut -d' ' -f6 | cut -c 1-40 >> ./tchashes

python3 xnu-qemu-arm64-tools/bootstrap_scripts/create_trustcache.py tchashes static_tc

umount ramFSMnt
umount ipswFSMnt

# git clone https://github.com/v1X3Q0/xnu-qemu-arm64

# cd xnu-qemu-arm64
# mkdir build-out
# cd build-out
# ../configure --target-list=aarch64-softmmu --disable-capstone --disable-pie --disable-slirp --enable-debug --enable-debug-info --disable-strip --prefix=$(pwd)/../outInst
# make -j4 CFLAGS=-D${IOS_VER}=1
# cd -

sed "s/048-32651-104.dmg.out/${ramFS}/g" starup.sh