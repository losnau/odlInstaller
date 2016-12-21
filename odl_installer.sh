#Available projects for this scirpt
projects=(aaa aalldp alto armoury atrium bier capwap cardinal centinel \
coretutorials daexim defense4all didm discovery dlux dluxapps docs eman faas \
federation genius groupbasedpolicy infrautils integration iotdm jsonrpc \
kafkaproducer l2switch lacp mdsal messaging4transport natapp nemo netconf \
netide netvirt net-virt-platform neutron next nic ocpplugin odlparent \
of-config opendove opflex packetcable persistence plugin2oc potn releng \
reservation sdninterfaceapp sfc snbi snmp snmp4sdn spectrometer sptn sxp \
systemmetrics tcpmd5 toolkit topoprocessing transportpce tsdr ttp unimgr \
usc usecplugin vpnservice yangide yang-push empty)


help()
{
	para="$1"
	echo "Usage:"
	echo "  $0 <project name> [<release>]"
	echo "  For example: "
	echo "    $0 dlux boron"
	echo "    $0 dlux"
	if [ "$1" == "" ]; then
		echo "Use \"empty\" for creating an ODL environment only" 
		echo "    $0 empty" 
	fi
	echo 
	echo "Bye!"
	echo ""
}

#Check if a string exists in a file
#file must be full path
string_exists()
{
	string=$1
	file=$2
	if [ -f "$file" ];then
		if  grep -q "$string" "$file"
		then
			echo "true";
			exit 0;
		fi
	fi
	echo "false"
}

###############################################################################
#
# Example: update_karaf_config "/etc/org.apache.karaf.features.cfg"
#
update_karaf_config()
{
  karaf_feature_cfg=$1;
  if [ ! -f "$karaf_feature_cfg" ]; then
     echo "false"
     exit 0
  fi

  curpath=$(pwd)
  cd ~
  home_path=$(pwd)
  dulx_feature=$(cat "$karaf_feature_cfg" | grep "featuresBoot=config" | grep "odl-dlux-all")
  #echo "dulx_feature1=$dulx_feature"
  
  if [ "$dulx_feature" == "" ]; then
    #echo "need to add"
    cat  "$karaf_feature_cfg" | awk -v feature="odl-dlux-all"  'BEGIN{FS=",";}{if ($1=="featuresBoot=config"){ $0=$0","feature; } print $0;}' > "$home_path/feture.x"
    sudo mv "$home_path/feture.x" "$karaf_feature_cfg"
    sudo chmod 664 "$karaf_feature_cfg"
  else
    echo "$karaf_feature_cfg updated already"
  fi

  dulx_feature=$(cat "$karaf_feature_cfg" | grep "featuresBoot=config=" | grep ",odl-dlux-all")
  if [ "$dulx_feature" == "" ]; then
   echo "false"
  else
    echo "true"
  fi
  
  cd "$curpath"
}


  
###############################################################################
# Parameter check
if  ([ $#  -ne 1  ] && [ $#  -ne 2  ] ); then
	help
	exit 0
fi

#Free RAM check
freeMem=$(free m | awk '{if ($1 == "Mem:" ) print $7;}' )
if [ $freeMem -lt 2097152 ]; then
	echo "Your free RAM is $freeMem, 2G(2097152) is suggested."
	exit 0;
fi

#Free HD check
freeHd=$(df -h | awk '{if ($1 == "/dev/sda1" ) print $2;}' | sed 's/G//g' )
if [ $freeHd -lt 20 ]; then
	echo Your free HD is "$freeHd"G, 20G is suggested.
	exit 0;
fi

me="$(whoami)"
project=$1
release=$2

# project name check
gerrit="false"

for i in "${projects[@]}"; do
	if [ ${i} == "$project" ]; then
		gerrit="true"
	fi
done

if [ "$gerrit" != "true" ]; then
	echo "Project $project doesn't exist in Gerrit"
	echo "Check your project in https://git.opendaylight.org/gerrit/ again"
	echo "Bye!"
	exit 0
fi

# release name check
if ( [ "$release" == "HEAD" ] || [ "$release" == "master" ] ); then
	release=""
else
	if ([ "$release" != "" ] && [ "$release" != "beryllium" ] && [ "$release" \
		!= "boron" ] && [ "$release" != "helium" ] \
		&& [ "$release" != "lithium" ]); then
		echo "release should be one of master/beryllium/boron/helium/lithium."
		echo ""
		help
		exit 0
	fi
fi 


###############################################################################
#
#1. Update system
#
#sudo apt-get update

cd ~
home_path=$(pwd)

###############################################################################
#
#2. Check sshd installation
#
sshd_path=$(which sshd)
#
if [ "$sshd_path" != "/usr/sbin/sshd" ]; then
	echo "Installing SSHD..."
	sudo apt-get install -y openssh-server
	sudo service sshd restart
fi

if [ ! -f "/etc/ssh/sshd_config.original" ]; then
	sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.original
	sudo chmod a-w /etc/ssh/sshd_config.original
fi

AuthorizedKeysFile=$(string_exists "#AuthorizedKeysFile"  \
		"/etc/ssh/sshd_config")

if [ "$AuthorizedKeysFile" == "true" ]; then
   cat /etc/ssh/sshd_config | sudo awk '{if ($1=="#AuthorizedKeysFile") \
	$0="AuthorizedKeysFile     %h/.ssh/authorized_keys"; print $0;}' \
		> $home_path/sshd_config.new
		
   sudo chmod 644  $home_path/sshd_config.new
   sudo mv $home_path/sshd_config.new /etc/ssh/sshd_config
   sudo service sshd restart
fi

AuthorizedKeysFile=$(string_exists "AuthorizedKeysFile" \
	"/etc/ssh/sshd_config")
#echo "AuthorizedKeysFile=$AuthorizedKeysFile"
if [ "$AuthorizedKeysFile" == "false" ]; then
        echo "AuthorizedKeysFile     %h/.ssh/authorized_keys " \
			>> "/etc/ssh/sshd_config"
fi

###############################################################################
#
#3. Check ODL Dvelopment Dependencies.
#Including:
#  pkg-config gcc make ant g++ git libboost-dev libcurl4-openssl-dev 
#  libjson0-dev libssl-dev openjdk-8-jdk unixodbc-dev xmlstarlet
#

# Check JDK8 installation
if [ ! -d "/usr/lib/jvm/java-8-openjdk-amd64" ]
then
	sudo apt-get install -y openjdk-8-jdk 
fi

# Check pkg-config installation
which_pkg_config=$(which  pkg-config)
if [ "$which_pkg_config" == "" ]; then
	sudo apt-get install -y pkg-config
fi

# Check gcc installation
which_gcc=$(which gcc)
if [ "$which_gcc" == "" ]; then
	sudo apt-get install -y gcc
fi

#Check make installation
which_make=$(which make)
if [ "$which_make" == "" ]; then
	sudo apt-get install -y make
fi

#Check ant installation
which_ant=$(which ant)
if [ "$which_ant" == "" ]; then
	sudo apt-get install -y ant
fi

#Check g++ installation
which_gplusplus=$(which g++)
if [ "$which_gplusplus" == "" ]; then
	sudo apt-get install -y g++
fi

#Check xmlstarlet installation
which_xmlstarlet=$(which xmlstarlet)
if [ "$which_xmlstarlet" == "" ]; then
	sudo apt-get install -y xmlstarlet
fi

#Check libboost-all-dev installation
if [ ! -d "/usr/include/boost" ]; then
	sudo apt-get install -y libboost-all-dev
	#sudo dpkg --configure -a
fi

#Check libcurl4-openssl-dev installation
if [ ! -d "/usr/include/curl" ]; then
	sudo apt-get install -y libcurl4-openssl-dev
fi

#Check libjson0-dev installation
if [ ! -d "/usr/include/json-c" ]; then
	sudo apt-get install -y libjson0-dev
fi

#Check libssl-dev installation
if [ ! -d "/usr/share/doc/libssl-dev" ]; then
	sudo apt-get install -y libssl-dev
fi

#Check unixodbc-dev installation
if [ ! -f "/var/lib/dpkg/info/unixodbc-dev.list" ]; then
	sudo apt-get install -y unixodbc-dev
fi

###############################################################################
#
#4. Maven installation
#
if [ ! -f "/usr/bin/mvn" ]; then
	sudo mkdir -p /usr/local/apache-maven 
	cd /usr/local/apache-maven
	sudo wget \
	http://apache.mirror.vexxhost.com/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz
	sudo tar -xzvf ./apache-maven-3.3.9-bin.tar.gz  -C /usr/local/apache-maven/
	sudo update-alternatives --install \
		/usr/bin/mvn mvn /usr/local/apache-maven/apache-maven-3.3.9/bin/mvn 1 
	sudo update-alternatives --config mvn
fi

###############################################################################
#
#5. Maven build configurations
#
export M2_HOME=/usr/local/apache-maven/apache-maven-3.3.9
export MAVEN_OPTS="-Xms512m -Xmx1024m"
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 


#5.1. Update "/etc/bash.bashrc"
if [ -f "/etc/bash.bashrc.original" ]; then
	sudo cp "/etc/bash.bashrc" "/etc/bash.bashrc.original"
fi

bashrcMemo=$(string_exists "#For ODL "  "/etc/bash.bashrc")

#echo "bashrcMemo=$bashrcMemo"
if [ "$bashrcMemo" == "false" ]; then
	cp /etc/bash.bashrc "$home_path/bash.bashrc"
	echo "" >> "$home_path/bash.bashrc"
	echo "#For ODL compilation" >> "$home_path/bash.bashrc"
	echo "export M2_HOME=/usr/local/apache-maven/apache-maven-3.3.9" \
				>> "$home_path/bash.bashrc"
	echo "export MAVEN_OPTS=\"-Xms512m -Xmx1024m\"" \
				>> "$home_path/bash.bashrc"
	echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 " \
				>> "$home_path/bash.bashrc"
	echo "" >> "$home_path/bash.bashrc"
	sudo mv "$home_path/bash.bashrc" /etc/bash.bashrc
	sudo chmod 644 /etc/bash.bashrc
fi


#5.2. Update MAVEN_OPTS in /usr/bin/mvn
if [ ! -f "/usr/bin/mvn.original" ]; then
	sudo cp /usr/bin/mvn   /usr/bin/mvn.original
fi

mvnMAVEN_OPTS=$(string_exists "MAVEN_OPTS=\"-Xms" $home_path/mvn.new)

if [ "$mvnMAVEN_OPTS" == "false" ]; then
	cat /usr/bin/mvn | awk \
	'{if (substr($0,1,11)=="MAVEN_OPTS=") $0="MAVEN_OPTS=\"-Xms512m -Xmx1024m\""; print $0; }' \
			> $home_path/mvn.new
	sudo chmod 755 $home_path/mvn.new
	sudo mv $home_path/mvn.new /usr/bin/mvn
fi

if [ ! -d "$home_path/.m2" ]; then
	mkdir "$home_path/.m2"
fi

#5.3. odlparent configuration
m2settings_flg=$(string_exists "<activeProfile>opendaylight-snapshots</activeProfile>" \
		"$home_path/.m2/settings.xml")

if [ "$m2settings_flg" == "false" ]; then
	curl https://raw.githubusercontent.com/opendaylight/odlparent/master/settings.xml \
				>  "$home_path/.m2/settings.xml"
	m2settings_flg=$(string_exists "<activeProfile>opendaylight-snapshots</activeProfile>" \
			"$home_path/.m2/settings.xml")
	if [ "$m2settings_flg" == "false" ]; then
		echo "Error:Failed to get https://raw.githubusercontent.com/opendaylight/odlparent/master/settings.xml"
		exit -1
	else
		sudo cp -n "$home_path/.m2/settings.xml"  /root/.m2/settings.xml
	fi
fi

###############################################################################
#
#6. GIT installation
#
if [ ! -f "/usr/bin/git" ]; then
	sudo apt install -y git
fi
git_link=$(which git)
if [ "$git_link" == "" ]; then
	echo "Failed to install GIT"
	exit -1
fi


#
#7. Bower installation
#
bowerpath=$(which bower)
nodejs=$(dpkg --get-selections | grep nodejs | awk '{print $2;exit;}')
if [ "$bowerpath" == "" ]; then
	sudo apt-get install -y python-software-properties
	curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash -
	sudo apt-get install -y nodejs
	sudo npm install -g bower
fi

mavenversion=$(mvn -v | grep "Apache Maven" | awk '{print $3;exit;}')
#echo "Maven version: $mavenversion"
if [ ! -f "$home_path/.odlreboot.log" ]; then
	date >  "$home_path/.odlreboot.log"
	echo "This virtual box needs reboot."
	echo "Press any key to reboot"
	read input_variable
	sudo reboot
fi
	
#exit if no project needs building
if [ "$project" == "empty" ]; then
    echo ""	
	echo "Your ODL environment is ready."
	help "no"
	exit 0
fi

###############################################################################
#
#8.  Download git repository of specified project source code from 
#    git.opendaylight.org
#    Available projects are in: https://git.opendaylight.org/gerrit/#/admin/
#                                                                  projects/
#    For example: git clone https://git.opendaylight.org/gerrit/p/dlux.git
#                 git clone https://git.opendaylight.org/gerrit/p/l2switch.git  
#
projectsBase="$home_path/projects"
if [ ! -d "$projectsBase" ]; then	
	mkdir -p "$projectsBase"
fi

projectdir="$projectsBase/$project"
sudo rm -rf "$projectdir"
cd "$projectsBase"

#8.1. Download specified source code from GIT
#8.1.1. download top level projects
for TOPPROJECT in odlparent affinity bgpcep controller lispflowmapping \
	openflowjava openflowplugin ovsdb vtn yangtools integration/distribution; \
do
	cd "$projectsBase"
	echo git clone https://git.opendaylight.org/gerrit/p/"$TOPPROJECT".git
	if [ -d "$projectsBase/$TOPPROJECT" ]; then
		rm -rf "$projectsBase/$TOPPROJECT"
	fi
	git clone https://git.opendaylight.org/gerrit/p/"$TOPPROJECT".git
done

#8.1.2. Checkout specified release version of top level projects
if [ "$release" != "" ]; then
  for PROJECT in odlparent bgpcep controller lispflowmapping openflowjava \
			openflowplugin ovsdb vtn yangtools distribution; \
  do
    cd "$projectsBase"
    cd "$PROJECT"
    git checkout stable/"$release"
    git fetch
  done
fi

#8.1.3. Build the specified release version of top level projects
for i in odlparent affinity bgpcep controller lispflowmapping openflowjava \
		openflowplugin ovsdb/commons/parent vtn yangtools
do
	cd "$projectsBase"
	if [ -d "$projectsBase/$i" ]; then
		cd "$i"
		#mvn clean install -Pq  -DskipTests
		rc=$?
		if [ $rc -ne 0 ] ; then
			echo "Failed to build top level project '$i'"
			exit -1
		fi
	fi
done

#8.1.4. Download the specified project 
cd "$projectsBase"
git clone https://git.opendaylight.org/gerrit/p/"$project".git

if [ ! -d "$projectdir" ]; then
	echo "Error: Failed to clone https://git.opendaylight.org/gerrit/$project"
	echo "Need to check network connection."
	exit -1
fi

if [ "$release" != "" ]; then
    cd "$projectdir"
    git fetch
    git checkout stable/"$release"
fi

if [ ! -f "$projectdir/pom.xml" ]; then
	echo "Error: Failed to clone https://git.opendaylight.org/gerrit/$project"
	exit -1
fi

#8.2. Check log folder
cd "$projectdir"
if [ ! -d "$home_path/logs" ]; then
	mkdir "$home_path/logs"
fi
logfile="$home_path/logs/$project.bulid.$(date +%Y-%m-%d-%H-%M-%S).log"
echo "log -> $logfile"
#rm -rf "$logfile"

###############################################################################
#8.3. Build project
mvn clean install -Pq -DskipTests #2 >>"$logfile"  1 >> "$logfile"

#8.4. Check karaf distribution
createdKaraf=$(ls $projectdir/distribution/karaf/target/distribution-karaf-*-SNAPSHOT.zip \
					2>/dev/null | awk '{print $0;exit ;}' ) 

if [ "$createdKaraf" == "" ]; then
	createdKaraf=$(ls $projectdir/karaf/target/distribution.*-karaf-*-SNAPSHOT.zip \
					2>/dev/null | awk '{print $0;exit ;}' ) 

	if [ "$createdKaraf" == "" ]; then	
		cd "$projectsBase"
		cd distribution
		mvn clean install -Pq -DskipTests
		
		#For dlux, re-build integration/distribution as I can't find distribution-karaf in it
		if [ "$project" == "dlux" ]; then
			
			karaf_feature_cfg="$projectsBase/distribution/distribution-karaf/target/assembly/etc/org.apache.karaf.features.cfg"
			update_karaf_config "$karaf_feature_cfg"
			
			if [ -f "$karaf_feature_cfg" ]; then
				update_karaf_config "$karaf_feature_cfg"
			else
				echo "Error: $karaf_feature_cfg missing"
			fi
		fi
			
		cp -rf "$projectsBase/distribution/distribution-karaf/target/assembly" \
				"$home_path/distribution-karaf"
	else
		cp -rf $projectdir/karaf/target/assembly "$home_path/distribution-karaf"
		
	fi
else
	cp -rf $projectdir/distribution/karaf/target/assembly "$home_path/distribution-karaf"
fi

if [ -f "$home_path/distribution-karaf/bin/karaf" ]; then
	echo "$home_path/distribution-karaf/bin/karaf is ready for $project"
	echo "Please take a SNAPSHOT of this Virtual box"
	echo "Start karaf:"
	echo "  cd $home_path/distribution-karaf/bin"
	echo "  ./karaf"
	echo ""
	echo "Good luck!"
else
	echo "Failed to figure out the karaf building issue. Please manually build the project"
fi
###############################################################################



