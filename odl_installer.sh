#   odlInstaller.sh
#

#
#1. Update system
#
sudo apt-get update

#
#2. Install JDK8
#
sudo apt-get install openjdk-8-jdk 

#
#3. Install Maven
#
mkdir -p /usr/local/apache-maven 
cd /usr/local/apache-maven
sudo wget http://apache.mirror.vexxhost.com/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz
sudo tar -xzvf ./apache-maven-3.3.9-bin.tar.gz  -C /usr/local/apache-maven/
sudo update-alternatives --install /usr/bin/mvn mvn /usr/local/apache-maven/apache-maven-3.3.9/bin/mvn 1 
sudo update-alternatives --config mvn
#sudo apt-get install maven

#
#4. Maven configurationo
#
export M2_HOME=/usr/local/apache-maven/apache-maven-3.3.9
export MAVEN_OPTS="-Xms256m -Xmx512m"
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 

echo "" >> /etc/bash.bashrc
echo "#For ODL compiling" >> /etc/bash.bashrc
echo "export M2_HOME=/usr/local/apache-maven/apache-maven-3.3.9" >> /etc/bash.bashrc
echo "export MAVEN_OPTS=\"-Xms256m -Xmx512m\"" >> /etc/bash.bashrc
echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 " >> /etc/bash.bashrc
echo "" >> /etc/bash.bashrc

echo "/etc/bash.bashrc has  been updated.""

sudo sed -i 's/.MAVEN_OPTS=.*/MAVEN_OPTS=\"-Xms256m -Xmx512m\"/' /usr/bin/mvn
me="$(whoami)"
if [ "$(whoami)" != 'root']
then
     mkdir ~/.m2
fi

if [ ! -d /root/.m2  ]
then
	sudo mkdir /root/.m2
fi

curl https://raw.githubusercontent.com/opendaylight/odlparent/master/settings.xml >  ~/.m2/settings.xml 

if [ ! -f ~/.m2/settings.xml ]
then
	echo "Error:Failed to get https://raw.githubusercontent.com/opendaylight/odlparent/master/settings.xml"
	exit 0
fi

rootM2Setting="/home/$me/.m2/settings.xml"
sudo cp "$rootM2Setting"  /root/.m2/settings.xml

#
#5.  Download git repository of specified project source code from Maven configuration
#    Available projects are in: https://git.opendaylight.org/gerrit/#/admin/projects/
#    For example:  git clone https://git.opendaylight.org/gerrit/dlux
#                  git clone https://git.opendaylight.org/gerrit/l2switch  
#

project=l2switch
projectdir="/home/$me/project/$project"
mkdir -p "$projectdir"
cd "$projectdir"
git clone "https://git.opendaylight.org/gerrit/$project"

cd "$projectdir/$project"
sudo mvn clean install -DskipTests

createdKaraf="$projectdir/$project/distribution/karaf/target/distribution-karaf-0.5.0-SNAPSHOT.zip"

if [ ! -f "$createdKaraf" ]; then
	echo "Error: Failed to build karaf "
	exit -1
fi

mkdir -p "~/distribution-karaf"
cp "$createdKaraf" "~/distribution-karaf/distribution-karaf-0.5.0-SNAPSHOT.zip"
#distribution/karaf/target/distribution-karaf-0.5.0-SNAPSHOT.zip
cd "~/distribution-karaf"
unzip distribution-karaf-0.5.0-SNAPSHOT.zip

if [ -f "~/distribution-karaf/distribution-karaf-0.5.0-SNAPSHOT/bin/karaf ]; then
  echo "Project $project has been built. Karaf is ~/distribution-karaf/distribution-karaf-0.5.0-SNAPSHOT/bin/karaf"
  echo "Please use karaf to install $project"
else
  echo "Error, failed to create   $project"
  exit 1
fi


