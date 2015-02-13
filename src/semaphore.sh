#/bin/sh

# check
CURRENT_COMMIT=`git rev-parse HEAD`

git submodule init data
git submodule update data
pushd data
DATA_COMMIT=`git rev-parse HEAD`
popd

if [ "${BRANCH_NAME}" = "master" ]; then
    DEPLOY_COMMIT=`curl --fail --silent http://redeclipse.net/files/devel/commit.txt`
    if [ -n "${DEPLOY_COMMIT}" ]; then
        DEPLOY_SRCFILES=`git diff --name-only HEAD ${DEPLOY_COMMIT} -- src`
        if [ -z "${DEPLOY_SRCFILES}" ]; then
            echo "No source files modified, skipping..."
            if [ "${CURRENT_COMMIT}" != "${DEPLOY_COMMIT}" ]; then
                echo "Module 'base' commit updated, syncing that: ${CURRENT_COMMIT} -> ${DEPLOY_COMMIT}"
                echo "${CURRENT_COMMIT}" > commit.txt
                scp -BC -i ${HOME}/.ssh/public_rsa -o StrictHostKeyChecking=no commit.txt qreeves@icculus.org:/webspace/redeclipse.net/files/devel/commit.txt
            fi
            DEPLOY_DATA=`curl --fail --silent http://redeclipse.net/files/devel/data.txt`
            if [ "${DATA_COMMIT}" != "${DEPLOY_DATA}" ]; then
                echo "Module 'data' commit updated, syncing that: ${DEPLOY_DATA} -> ${DATA_COMMIT}"
                echo "${DATA_COMMIT}" > data.txt
                scp -BC -i ${HOME}/.ssh/public_rsa -o StrictHostKeyChecking=no data.txt qreeves@icculus.org:/webspace/redeclipse.net/files/devel/data.txt
            fi
            exit 0
        else
            echo "Source files modified, proceeding with build..."
            echo ""
        fi
    fi
fi

#setup
CMD_APT="DEBIAN_FRONTEND=noninteractive apt-get"
mkdir -pv ${SEMAPHORE_CACHE_DIR}/apt/archives/partial
sudo cp -ruv /var/cache/apt ${SEMAPHORE_CACHE_DIR}/apt
sudo rm -rfv /var/cache/apt
sudo ln -sv ${SEMAPHORE_CACHE_DIR}/apt /var/cache/apt
sudo dpkg --add-architecture i386
sudo ${CMD_APT} update

#build
sudo ${CMD_APT} -fy install build-essential zlib1g-dev libsdl-mixer1.2-dev libsdl-image1.2-dev
make PLATFORM=linux64 PLATFORM_BIN=amd64 INSTDIR=${HOME}/build/${BRANCH_NAME}/linux/bin/amd64 CFLAGS=-m64 CXXFLAGS=-m64 LDFLAGS=-m64 -C src clean install || exit 1
if [ "${BRANCH_NAME}" = "master" ]; then
    sudo ${CMD_APT} -fy install binutils-mingw-w64 g++-mingw-w64
    make PLATFORM=crossmingw64 PLATFORM_BIN=amd64 INSTDIR=${HOME}/build/${BRANCH_NAME}/windows/bin/amd64 CFLAGS=-m64 CXXFLAGS=-m64 LDFLAGS=-m64 -C src clean install || exit 1
    make PLATFORM=crossmingw32 PLATFORM_BIN=x86 INSTDIR=${HOME}/build/${BRANCH_NAME}/windows/bin/x86 CFLAGS=-m32 CXXFLAGS=-m32 LDFLAGS=-m32 -C src clean install || exit 1
    sudo ${CMD_APT} -fy remove zlib1g-dev libsdl1.2-dev libsdl-mixer1.2-dev libsdl-image1.2-dev libpng-dev
    sudo ${CMD_APT} -fy autoremove
    sudo ${CMD_APT} -fy install build-essential multiarch-support g++-multilib zlib1g-dev:i386 libsdl1.2-dev:i386 libsdl-mixer1.2-dev:i386 libsdl-image1.2-dev:i386 libpng-dev:i386
    make PLATFORM=linux32 PLATFORM_BIN=x86 INSTDIR=${HOME}/build/${BRANCH_NAME}/linux/bin/x86 CFLAGS=-m32 CXXFLAGS=-m32 LDFLAGS=-m32 -C src clean install || exit 1
fi

#deploy
if [ "${BRANCH_NAME}" = "master" ] && [ -n "${DEPLOY_COMMIT}" ]; then
    pushd ${HOME}/build/${BRANCH_NAME} || exit 1
    rm -fv version.txt windows.zip linux.tar.bz2
    pushd windows || exit 1
    zip -r ../windows.zip .
    popd
    pushd linux || exit 1
    tar -jcvf ../linux.tar.bz2 .
    popd
    date +%Y%m%d%H%M%S > version.txt
    echo "${CURRENT_COMMIT}" > commit.txt
    echo "${DATA_COMMIT}" > data.txt
    scp -BC -i ${HOME}/.ssh/public_rsa -o StrictHostKeyChecking=no windows.zip qreeves@icculus.org:/webspace/redeclipse.net/files/devel/windows.zip
    scp -BC -i ${HOME}/.ssh/public_rsa -o StrictHostKeyChecking=no linux.tar.bz2 qreeves@icculus.org:/webspace/redeclipse.net/files/devel/linux.tar.bz2
    scp -BC -i ${HOME}/.ssh/public_rsa -o StrictHostKeyChecking=no version.txt qreeves@icculus.org:/webspace/redeclipse.net/files/devel/version.txt
    scp -BC -i ${HOME}/.ssh/public_rsa -o StrictHostKeyChecking=no commit.txt qreeves@icculus.org:/webspace/redeclipse.net/files/devel/commit.txt
    scp -BC -i ${HOME}/.ssh/public_rsa -o StrictHostKeyChecking=no data.txt qreeves@icculus.org:/webspace/redeclipse.net/files/devel/data.txt
    popd
fi
