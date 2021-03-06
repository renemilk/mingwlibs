#!/bin/sh
BOOST_VERSION=1_48_0
BOOST_LIBS="test thread system filesystem regex program_options signals"
SPRING_HEADERS="${BOOST_LIBS} format ptr_container spirit algorithm date_time asio"
ASSIMP_HEADERS="math/common_factor smart_ptr"
BOOST_HEADERS="${SPRING_HEADERS} ${ASSIMP_HEADERS}"
BOOST_CONF=./user-config.jam

# Setting system dependent vars
BOOST_BUILD_DIR=/tmp/build-boost
MINGWLIBS_DIR=~/boostlibs/mingwlibs/
# x86 or x86_64
MINGW_GPP=/usr/bin/i686-mingw32-g++
MINGW_RANLIB=i686-mingw32-ranlib


BOOST_LIBS_ARG=""
for LIB in $BOOST_LIBS
do
	BOOST_LIBS_ARG="${BOOST_LIBS_ARG} --with-${LIB}"
done


#############################################################################################################

# Setup final structure
rm -f ${MINGWLIBS_DIR}lib/libboost* 2>/dev/null
rm -Rf ${MINGWLIBS_DIR}include/boost 2>/dev/null
mkdir -p ${MINGWLIBS_DIR}lib/ 2>/dev/null
mkdir -p ${MINGWLIBS_DIR}include/boost/ 2>/dev/null


# bootstrap bjam
cd boost_${BOOST_VERSION}/
./bootstrap.sh


# Building bcp - boosts own filtering tool
cd tools/bcp
../../bjam --build-dir=${BOOST_BUILD_DIR}
cd ../..
cp $(ls ${BOOST_BUILD_DIR}/boost/*/tools/bcp/*/*/*/bcp) .


# Building the required libraries
echo "using gcc : : ${MINGW_GPP} ;" > ${BOOST_CONF}
./bjam \
    --build-dir="${BOOST_BUILD_DIR}" \
    --stagedir="${MINGWLIBS_DIR}" \
    --user-config=${BOOST_CONF} \
    --debug-building \
    ${BOOST_LIBS_ARG} \
    variant=release \
    target-os=windows \
    threadapi=win32 \
    threading=multi \
    link=static \
    toolset=gcc \


# fix library names (libboost_thread_win32.a -> libboost_thread-mt.a)
for f in $(ls ${MINGWLIBS_DIR}lib/*.a); do
	FIXEDBASENAME=$(basename "$f" | sed -e 's/_win32//' | sed -e 's/\.a/-mt\.a/' )
	mv "$f" "${MINGWLIBS_DIR}lib/$FIXEDBASENAME"
done


# Adding symbol tables to the libs (this should not be required anymore in boost 1.43+)
for f in $(ls ${MINGWLIBS_DIR}lib/libboost_*.a); do
	${MINGW_RANLIB} "$f";
done


# Copying the headers to MinGW-libs
rm -Rf ${BOOST_BUILD_DIR}/filtered
mkdir ${BOOST_BUILD_DIR}/filtered
./bcp ${BOOST_HEADERS} ${BOOST_BUILD_DIR}/filtered &> /dev/null
cp -r ${BOOST_BUILD_DIR}/filtered/boost ${MINGWLIBS_DIR}include/


# we always use pthreads (even on windows!)
#echo "#define BOOST_THREAD_POSIX" >> "${MINGWLIBS_DIR}include/boost/config/user.hpp"
echo "#define BOOST_THREAD_USE_LIB" >> "${MINGWLIBS_DIR}include/boost/config/user.hpp"
