
VM_NAMTE=$1
IPHONE_VER=$2
IOS_VER=$3
# COPY_BLK=$4
# USE_BUILTIN=$5
unzip ${VM_NAMTE}
PATH_PREFIX=~/repos

if [ -z ${USE_BUILTIN} ]
then
    wget https://github.com/alephsecurity/xnu-qemu-arm64-tools/archive/master.zip
    unzip master.zip
    mv xnu-qemu-arm64-tools-master xnu-qemu-arm64-tools
    rm -rf master.zip
    PATH_PREFIX=.
fi

kernelcacheBase=()
myfilesize=0
tmpfilesize=0

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

python3 ${PATH_PREFIX}/xnu-qemu-arm64-tools/bootstrap_scripts/asn1kerneldecode.py ${kernelcacheBase} ${kernelcacheBase}.asn1decoded
if [[ "${IPHONE_VER}" == "n104ap" ]]
then
    lzfse -decode -i ${kernelcacheBase}.asn1decoded -o ${kernelcacheBase}.out
elif [[ "${IPHONE_VER}" == "n66ap" ]]
then
    python3 ${PATH_PREFIX}/xnu-qemu-arm64-tools/bootstrap_scripts/decompress_lzss.py ${kernelcacheBase}.asn1decoded ${kernelcacheBase}.out
else
    echo Need a specified iphone device prefix, not ${IPHONE_VER}
    exit
fi

if [[ "${IOS_VER}" == "IOS_14_0" ]]
then
    python3 ${PATH_PREFIX}/xnu-qemu-arm64-tools/bootstrap_scripts/asn1dtredecode.py Firmware/all_flash/DeviceTree.${IPHONE_VER}.im4p Firmware/all_flash/DeviceTree.${IPHONE_VER}.im4p.asn1decoded
    lzfse -decode -i Firmware/all_flash/DeviceTree.${IPHONE_VER}.im4p.asn1decoded -o Firmware/all_flash/DeviceTree.${IPHONE_VER}.im4p.out
else
    python3 ${PATH_PREFIX}/xnu-qemu-arm64-tools/bootstrap_scripts/asn1dtredecode.py Firmware/all_flash/DeviceTree.${IPHONE_VER}.im4p Firmware/all_flash/DeviceTree.${IPHONE_VER}.im4p.out
fi

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

touch ./tchashes

# cause I don't have resize yet:
if [ ${COPY_BLK} -eq 1 ]
then
    if [ -f ~/store/ipsw/ramfsExt/${ramFS}.out ]
    then
        cp ~/store/ipsw/ramfsExt/${ramFS}.out ${ramFS}.out
    else
        echo Need the ipsw file ${ramFS} to exists
        exit
    fi
else
    python3 ${PATH_PREFIX}/xnu-qemu-arm64-tools/bootstrap_scripts/asn1rdskdecode.py ${ramFS} ${ramFS}.out
    mntVolRam=ramFSMnt
    mntVolFS=ipswFSMnt
    # PeaceXXXXXX.arm64UpdateRamDisk
    mkdir ${mntVolRam}
    darling-dmg ${ramFS} ${mntVolRam}
    # not peace
    mkdir ${mntVolFS}
    darling-dmg ${ipswFS} ${mntVolFS}

    sudo mkdir -p ${mntVolRam}/System/Library/Caches/com.apple.dyld/
    sudo cp ${mntVolFS}/System/Library/Caches/com.apple.dyld/dyld_shared_cache_arm64 ${mntVolRam}/System/Library/Caches/com.apple.dyld/
    sudo chown root ${mntVolRam}/System/Library/Caches/com.apple.dyld/dyld_shared_cache_arm64

    if [ -z ${USE_BUILTIN} ]
    then
        wget https://github.com/jakeajames/rootlessJB/archive/master.zip
        unzip master.zip
        mv rootlessJB-master rootlessJB
        rm -rf master.zip
        
        cd rootlessJB/rootlessJB/bootstrap/tars/
        tar xvf iosbinpack.tar
        cd -
    fi

    sudo cp -R ${PATH_PREFIX}/rootlessJB/rootlessJB/bootstrap/tars/iosbinpack64 ${mntVolRam}
    sudo rm ${mntVolRam}/System/Library/LaunchDaemons/*
    sudo cp bash.plist ${mntVolRam}/System/Library/LaunchDaemons/bash.plist

    for filename in $(find ${mntVolRam}/iosbinpack64 -type f); do jtool --sig --ent $filename 2>/dev/null; done | grep CDHash | cut -d' ' -f6 | cut -c 1-40 >> ./tchashes
    
    python3 ${PATH_PREFIX}/xnu-qemu-arm64-tools/bootstrap_scripts/create_trustcache.py tchashes static_tc

    umount ${mntVolFS}
    umount ${mntVolRam}
fi

if [ -z ${USE_BUILTIN} ]
then
    git clone https://github.com/v1X3Q0/xnu-qemu-arm64

    cd xnu-qemu-arm64
    mkdir build-out
    cd build-out
    ../configure --target-list=aarch64-softmmu --disable-capstone --disable-pie --disable-slirp --enable-debug --enable-debug-info --disable-strip --prefix=$(pwd)/../outInst
    make -j4 CFLAGS=-D${IOS_VER}=1
    cd -
fi

sed "s/048-32651-104.dmg.out/${ramFS}/g" starup.sh
