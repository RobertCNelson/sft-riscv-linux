#!/bin/bash -e
#
# Copyright (c) 2009-2021 Robert Nelson <robertcnelson@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# Split out, so build_kernel.sh and build_deb.sh can share..

shopt -s nullglob

. ${DIR}/version.sh
if [ -f ${DIR}/system.sh ] ; then
	. ${DIR}/system.sh
fi
git_bin=$(which git)
#git hard requirements:
#git: --no-edit

git="${git_bin} am"
git_patchset="https://github.com/starfive-tech/linux"
#git_opts

if [ "${RUN_BISECT}" ] ; then
	git="${git_bin} apply"
fi

echo "Starting patch.sh"

git_add () {
	${git_bin} add .
	${git_bin} commit -a -m 'testing patchset'
}

start_cleanup () {
	git="${git_bin} am --whitespace=fix"
}

cleanup () {
	if [ "${number}" ] ; then
		if [ "x${wdir}" = "x" ] ; then
			${git_bin} format-patch -${number} -o ${DIR}/patches/
		else
			if [ ! -d ${DIR}/patches/${wdir}/ ] ; then
				mkdir -p ${DIR}/patches/${wdir}/
			fi
			${git_bin} format-patch -${number} -o ${DIR}/patches/${wdir}/
			unset wdir
		fi
	fi
	exit 2
}

dir () {
	wdir="$1"
	if [ -d "${DIR}/patches/$wdir" ]; then
		echo "dir: $wdir"

		if [ "x${regenerate}" = "xenable" ] ; then
			start_cleanup
		fi

		number=
		for p in "${DIR}/patches/$wdir/"*.patch; do
			${git} "$p"
			number=$(( $number + 1 ))
		done

		if [ "x${regenerate}" = "xenable" ] ; then
			cleanup
		fi
	fi
	unset wdir
}

cherrypick () {
	if [ ! -d ../patches/${cherrypick_dir} ] ; then
		mkdir -p ../patches/${cherrypick_dir}
	fi
	${git_bin} format-patch -1 ${SHA} --start-number ${num} -o ../patches/${cherrypick_dir}
	num=$(($num+1))
}

external_git () {
	git_tag="Fedora"
	echo "pulling: [${git_patchset} ${git_tag}]"
	${git_bin} pull --no-edit ${git_patchset} ${git_tag}
	top_of_branch=$(${git_bin} describe)
	if [ ! "x${git_new_commit}" = "x" ] ; then
		${git_bin} checkout master -f
		test_for_branch=$(${git_bin} branch --list "v${KERNEL_TAG}${BUILD}")
		if [ "x${test_for_branch}" != "x" ] ; then
			${git_bin} branch "v${KERNEL_TAG}${BUILD}" -D
		fi
		${git_bin} checkout ${git_new_commit} -b v${KERNEL_TAG}${BUILD} -f
		current_git=$(${git_bin} describe)
		echo "${current_git}"

		if [ ! "x${top_of_branch}" = "x${current_git}" ] ; then
			echo "INFO: external git repo has updates..."
		fi
	else
		echo "${top_of_branch}"
	fi
	#exit 2
}

rt_cleanup () {
	echo "rt: needs fixup"
	exit 2
}

rt () {
	rt_patch="${KERNEL_REL}${kernel_rt}"

	#${git_bin} revert --no-edit xyz

	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		wget -c https://www.kernel.org/pub/linux/kernel/projects/rt/${KERNEL_REL}/patch-${rt_patch}.patch.xz
		xzcat patch-${rt_patch}.patch.xz | patch -p1 || rt_cleanup
		rm -f patch-${rt_patch}.patch.xz
		rm -f localversion-rt
		${git_bin} add .
		${git_bin} commit -a -m 'merge: CONFIG_PREEMPT_RT Patch Set' -m "patch-${rt_patch}.patch.xz" -s
		${git_bin} format-patch -1 -o ../patches/rt/
		echo "RT: patch-${rt_patch}.patch.xz" > ../patches/git/RT

		exit 2
	fi

	dir 'rt'
}

dtb_makefile_append_omap4 () {
	sed -i -e 's:omap4-panda.dtb \\:omap4-panda.dtb \\\n\t'$device' \\:g' arch/arm/boot/dts/Makefile
}

dtb_makefile_append () {
	sed -i -e 's:am335x-boneblack.dtb \\:am335x-boneblack.dtb \\\n\t'$device' \\:g' arch/arm/boot/dts/Makefile
}

beagleboard_dtbs () {
	branch="v5.12.x"
	https_repo="https://github.com/beagleboard/BeagleBoard-DeviceTrees"
	work_dir="BeagleBoard-DeviceTrees"
	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		cd ../
		if [ ! -d ./${work_dir} ] ; then
			${git_bin} clone -b ${branch} ${https_repo} --depth=1
			cd ./${work_dir}
				git_hash=$(git rev-parse HEAD)
			cd -
		else
			rm -rf ./${work_dir} || true
			${git_bin} clone -b ${branch} ${https_repo} --depth=1
			cd ./${work_dir}
				git_hash=$(git rev-parse HEAD)
			cd -
		fi
		cd ./KERNEL/

		mkdir -p arch/arm/boot/dts/overlays/
		cp -vr ../${work_dir}/src/arm/* arch/arm/boot/dts/
		cp -vr ../${work_dir}/include/dt-bindings/* ./include/dt-bindings/

		#device="omap4-panda-es-b3.dtb" ; dtb_makefile_append_omap4

		#device="am335x-abbbi.dtb" ; dtb_makefile_append
		#device="am335x-bonegreen-gateway.dtb" ; dtb_makefile_append

		#device="am335x-boneblack-uboot.dtb" ; dtb_makefile_append

		#device="am335x-bone-uboot-univ.dtb" ; dtb_makefile_append
		#device="am335x-boneblack-uboot-univ.dtb" ; dtb_makefile_append
		#device="am335x-bonegreen-wireless-uboot-univ.dtb" ; dtb_makefile_append

		${git_bin} add -f arch/arm/boot/dts/
		${git_bin} add -f include/dt-bindings/
		${git_bin} commit -a -m "Add BeagleBoard.org DTBS: $branch" -m "${https_repo}/tree/${branch}" -m "${https_repo}/commit/${git_hash}" -s
		${git_bin} format-patch -1 -o ../patches/soc/ti/beagleboard_dtbs/
		echo "BBDTBS: ${https_repo}/commit/${git_hash}" > ../patches/git/BBDTBS

		rm -rf ../${work_dir}/ || true

		${git_bin} reset --hard HEAD^

		start_cleanup

		${git} "${DIR}/patches/soc/ti/beagleboard_dtbs/0001-Add-BeagleBoard.org-DTBS-$branch.patch"

		wdir="soc/ti/beagleboard_dtbs"
		number=1
		cleanup
	fi

	dir 'soc/ti/beagleboard_dtbs'
}

local_patch () {
	echo "dir: dir"
	${git} "${DIR}/patches/dir/0001-patch.patch"
}

external_git
#rt
#beagleboard_dtbs
#local_patch

pre_backports () {
	echo "dir: backports/${subsystem}"

	cd ~/linux-src/
	${git_bin} pull --no-edit https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git master
	${git_bin} pull --no-edit https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git master --tags
	${git_bin} pull --no-edit https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git master --tags
	if [ ! "x${backport_tag}" = "x" ] ; then
		${git_bin} checkout ${backport_tag} -b tmp
	fi
	cd -
}

post_backports () {
	if [ ! "x${backport_tag}" = "x" ] ; then
		cd ~/linux-src/
		${git_bin} checkout master -f ; ${git_bin} branch -D tmp
		cd -
	fi

	rm -f arch/arm/boot/dts/overlays/*.dtbo || true
	${git_bin} add .
	${git_bin} commit -a -m "backports: ${subsystem}: from: linux.git" -m "Reference: ${backport_tag}" -s
	if [ ! -d ../patches/backports/${subsystem}/ ] ; then
		mkdir -p ../patches/backports/${subsystem}/
	fi
	${git_bin} format-patch -1 -o ../patches/backports/${subsystem}/
}

patch_backports (){
	echo "dir: backports/${subsystem}"
	${git} "${DIR}/patches/backports/${subsystem}/0001-backports-${subsystem}-from-linux.git.patch"
}

backports () {
	backport_tag="xyz"

	subsystem="xyz"
	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		pre_backports

		cp -rv ~/linux-src/drivers/net/wireless/ti/* ./drivers/net/wireless/ti/

		post_backports
		exit 2
	else
		patch_backports
	fi
}

reverts () {
	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		start_cleanup
	fi

	## notes
	##git revert --no-edit xyz -s

	dir 'reverts'

	if [ "x${regenerate}" = "xenable" ] ; then
		wdir="reverts"
		number=1
		cleanup
	fi
}

#drivers () {
#
#}

#soc () {
#
#}

###
#backports
#reverts
#drivers
#soc
dir '3mdeb/linux/'

#dir 'dts'
dir 'rcnee_hacks'
wget -c https://raw.githubusercontent.com/starfive-tech/u-boot/Fedora/arch/riscv/dts/starfive_vic7100_beagle_v.dts -P ../patches/
wget -c https://raw.githubusercontent.com/starfive-tech/u-boot/Fedora/arch/riscv/dts/starfive_vic7100_clk.dtsi -P ../patches/

packaging () {
	#do_backport="enable"
	if [ "x${do_backport}" = "xenable" ] ; then
		backport_tag="v5.10.32"

		subsystem="bindeb-pkg"
		#regenerate="enable"
		if [ "x${regenerate}" = "xenable" ] ; then
			pre_backports

			cp -v ~/linux-src/scripts/package/* ./scripts/package/

			post_backports
			exit 2
		else
			patch_backports
		fi
	fi

	${git} "${DIR}/patches/backports/bindeb-pkg/0002-builddeb-Install-our-dtbs-under-boot-dtbs-version.patch"
}

packaging
echo "patch.sh ran successfully"
