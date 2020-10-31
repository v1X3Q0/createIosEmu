
VM_NAMTE=$1
IOS_VER=$2
unzip ${VM_NAMTE}

wget https://github.com/alephsecurity/xnu-qemu-arm64-tools/archive/master.zip
unzip master.zip
mv xnu-qemu-arm64-tools-master xnu-qemu-arm64-tools
rm -rf master.zip

for filename in ./kernelcache*; do
    tmpfilesize=$(wc -c "${filename}" | awk '{print $1}')
    if [ ${myfilesize} -eq 0 ]
    then
        kernelcacheBase=${filename}
        myfilesize=${tmpfilesize}
    else
        tmpfilesize=$(wc -c "${filename}" | awk '{print $1}')
        if [ ${tmpfilesize} -ge ${myfilesize} ]
        then
            kernelcacheBase=${filename}
            myfilesize=${tmpfilesize}
        fi
    fi    
done

python3 xnu-qemu-arm64-tools/bootstrap_scripts/asn1kerneldecode.py ${kernelcacheBase} ${kernelcacheBase}.asn1decoded
if [ ${IPHONE_VER} -eq n104ap ]
then
    lzfse -decode -i ${kernelcacheBase}.asn1decoded -o ${kernelcacheBase}.out
elif [ ${IPHONE_VER} -eq n66ap ]
then
    python3 xnu-qemu-arm64-tools/bootstrap_scripts/decompress_lzss.py ${kernelcacheBase}.asn1decoded ${kernelcacheBase}.out
fi
python3 xnu-qemu-arm64-tools/bootstrap_scripts/asn1dtredecode.py Firmware/all_flash/DeviceTree.${2}.im4p Firmware/all_flash/DeviceTree.${2}.im4p.out

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


python3 xnu-qemu-arm64-tools/bootstrap_scripts/asn1rdskdecode.py ${ramFS} ${ramFS}.out

hdiutil resize -size 2.0G -imagekey diskimage-class=CRawDiskImage ${ramFS}.out
# PeaceXXXXXX.arm64UpdateRamDisk
mntVolRam=$(hdiutil attach -imagekey diskimage-class=CRawDiskImage ${ramFS}.out | awk '{print $2}')
sudo diskutil enableownership ${mntVolRam}
# not peace
mntVolFS=$(hdiutil attach ${ipswFS} | grep Volumes | awk '{print $3}')

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

hdiutil detach ${mntVolRam}
hdiutil detach ${mntVolFS}   

git clone https://github.com/v1X3Q0/xnu-qemu-arm64

cd xnu-qemu-arm64
mkdir build-out
cd build-out
../configure --target-list=aarch64-softmmu --disable-capstone --disable-pie --disable-slirp --enable-debug --enable-debug-info --disable-strip --prefix=$(pwd)/../outInst
make -j4 CFLAGS=-D${IOS_VER}=1
cd -

sed "s/048-32651-104.dmg.out/${ramFS}/g" starup.sh
