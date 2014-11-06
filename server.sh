#!/bin/sh

USER=`whoami`
system_version=`lsb_release -i`
SSH_KEY_GEN_FLAG=1
trap 'echo;echo Term signal catched, exit now!;reset -I; exit 1' INT

function usage()
{
	echo "Usage: ./gitolite ***.pub "
	echo "	(The ***.pub should be the admin's ssh public key)"
	exit 1
}

if [ `id -u` -ne 0 ]; then
	echo "You are not root user, Please run this script with root"
	exit 1
fi

if [ $# -ne 1 ]; then
	usage
	exit 1
fi

while [ ! $GITOLITE_USER ]
do
	read -p "Which user do you want to install gitolite: " GITOLITE_USER
	if [ "$GITOLITE_USER" = "root" ]; then
		echo "gitolite do not support root user, please use other user"
		GITOLITE_USER=''
	fi
done

if [ -f /home/$GITOLITE_USER/.gitolite.rc -a -d /home/$GITOLITE_USER/.gitolite -a -d /home/$GITOLITE_USER/repositories ]; then
	read -p "gitolite has already been installed in user $GITOLITE_USER, do you want to re-install (y/N)?" gitolite_cover
	if [ "$gitolite_cover" = "y" ]; then
		rm -fr /home/$GITOLITE_USER/.gitolite.rc
		rm -fr /home/$GITOLITE_USER/.gitolite
		rm -fr /home/$GITOLITE_USER/repositories
	else
		echo 
		echo "exiting..."
		exit 0
	fi
fi


# check if the user exist, if not, create it
if ! egrep "$GITOLITE_USER" /etc/passwd >> /dev/null; then
        echo " "
        echo "User $GITOLITE_USER do not exist, create it"
        adduser $GITOLITE_USER
fi

SSH_CONFIG_FILE=/home/$GITOLITE_USER/.ssh/config
[ -d /home/$GITOLITE_USER/.ssh ] || su $GITOLITE_USER -c "mkdir /home/$GITOLITE_USER/.ssh -p"; 

su $GITOLITE_USER -c "echo \"host netmoon\" > $SSH_CONFIG_FILE "
su $GITOLITE_USER -c "echo \"  user git\" >> $SSH_CONFIG_FILE"
while [ ! -n "$serverip" ]
do
	read -p "Git Server Ip: " serverip
done
su $GITOLITE_USER -c "echo \"  hostname $serverip\" >> $SSH_CONFIG_FILE"
su $GITOLITE_USER -c "echo \"  port 22\" >> $SSH_CONFIG_FILE"

echo "What the name of ssh key?"
echo "(For example: If you want your ssh key named: \"user.pub\" ,please enter \"user\")"
while [ ! -n "$identityfile" ]
do
	read -p "identityfile: " identityfile 
done
su $GITOLITE_USER -c "echo \"  identityfile ~/.ssh/$identityfile\" >> $SSH_CONFIG_FILE"
if [ -f /home/$GITOLITE_USER/.ssh/$identityfile -a -f /home/$GITOLITE_USER/.ssh/$identityfile\.pub ]; then
	tmp='N'
	echo "/home/$GITOLITE_USER/.ssh/$identityfile already exists."
	read -p "Overwrite (y/N)?" tmp
	if [ "$tmp" = "y" -o "$tmp" = "Y" ]; then
		SSH_KEY_GEN_FLAG=1
		rm /home/$GITOLITE_USER/.ssh/$identityfile* -rf
	else
		SSH_KEY_GEN_FLAG=0
	fi
fi

if [ $SSH_KEY_GEN_FLAG -eq 1 ]; then
	while true
	do
		read -p "Enter passphrase (empty for no passphrase):" -s passwd
		echo
		read -p "Enter same passphrase again::" -s copy_passwd
		if [ "$passwd" != "$copy_passwd" ]; then
			echo "Passphrases do not match.  Try again."
			continue
		fi
		if [ -z "$passwd" -o "$passwd" = "\n" -o "$passwd" = "\r" -o "$passwd" = "\n\r" ]; then
			break
		else
			LENGTH=`expr length $passwd`
			if [ $LENGTH -le 4 ]; then
				echo "passphrase too short: have $LENGTH bytes, need > 4" 
			else
				break
			fi
		fi
	done

	echo 

	if [ -z "$passwd" -o "$passwd" = "\n" -o "$passwd" = "\r" -o "$passwd" = "\n\r" ]; then
		su $GITOLITE_USER -c "ssh-keygen -N \"\" -f /home/$GITOLITE_USER/.ssh/$identityfile"
	else
		su $GITOLITE_USER -c "ssh-keygen -N $passwd -f /home/$GITOLITE_USER/.ssh/$identityfile"
	fi
fi
		#cp config $HOME/.ssh;
chmod 600 $SSH_CONFIG_FILE

if [ ! -e "/home/$GITOLITE_USER/.gitconfig" ]; then
	echo "Config the git, ***Please tell me who you are"
	while [ ! GIT_USER ]
	do
		read -p "Your name: " GIT_USER
	done
	su $GITOLITE_USER -c "git config --global user.name $GIT_USER"

	while [ ! GIT_USER_EMAIL ]
	do
		read -p "Your email: " GIT_USER_EMAIL
	done
	su $GITOLITE_USER -c "git config --global user.name $GIT_USER_EMAIL"
else
	user_repeat="y"
	email_repeat="y"
	GIT_USER=`su $GITOLITE_USER -c "git config --get user.name"`
	read -p "Your name: $GIT_USER (Y/n)?" user_repeat
	if [ "$user_repeat" = "n" ]; then
		while [ ! $GIT_USER_TMP ]
		do
			read -p "Your name: " GIT_USER_TMP
		done
		su $GITOLITE_USER -c "git config --global user.name $GIT_USER_TMP"
	fi
	GIT_USER_EMAIL=`su $GITOLITE_USER -c "git config --get user.email"`
	read -p "Your email: $GIT_USER_EMAIL (Y/n)?" email_repeat 
	if [ "$email_repeat" = "n" ]; then
		while [ ! $GIT_USER_EMAIL_TMP ]
		do
			read -p "Your email: " GIT_USER_EMAIL_TMP
		done
		su $GITOLITE_USER -c "git config --global user.email $GIT_USER_EMAIL_TMP"
	fi
fi

echo "installing gitolite..."

rm -fr /home/$GITOLITE_USER/.gitolite.rc
rm -fr /home/$GITOLITE_USER/.gitolite
rm -fr /home/$GITOLITE_USER/repositories

#chown $GITOLITE_USER:$GITOLITE_USER gitolite.tar.bz2
tar jxf gitolite.tar.bz2 -C /home/$GITOLITE_USER
su $GITOLITE_USER -c "mkdir -p ~/bin"
su $GITOLITE_USER -c "~/gitolite/install -to ~/bin"
cp $1 /home/$GITOLITE_USER/ 
chmod 666 /home/$GITOLITE_USER/`basename $1`
chown $GITOLITE_USER:$GITOLITE_USER /home/$GITOLITE_USER/`basename $1`
su $GITOLITE_USER -c "~/bin/gitolite setup -pk ~/`basename $1`"
if [ $? -ne 0 ]; then
	exit 1
fi

#su $GITOLITE_USER -c "sed -i '/'\''cgit'\''/s/#//g' ~/.gitolite.rc"
#su $GITOLITE_USER -c "sed -i '/'\''mirror'\''/s/#//g' ~/.gitolite.rc"
#su $GITOLITE_USER -c "sed -i '/'\''Mirroring'\''/s/#//g' ~/.gitolite.rc"
#su $GITOLITE_USER -c "sed -i '/GIT_CONFIG_KEYS/s/'\'''\''/'\''.*'\''/' ~/.gitolite.rc"
#su $GITOLITE_USER -c "sed -i '/#\{1,\} *HOSTNAME/s/#//g' ~/.gitolite.rc"
cp gitolite.rc /home/$GITOLITE_USER/.gitolite.rc
chmod 600 /home/$GITOLITE_USER/.gitolite.rc
chown $GITOLITE_USER:$GITOLITE_USER /home/$GITOLITE_USER/.gitolite.rc
su $GITOLITE_USER -c "cp post-receive ~/.gitolite/hooks/common/"
su $GITOLITE_USER -c "chmod a+x ~/.gitolite/hooks/common/post-receive"
su $GITOLITE_USER -c "~/bin/gitolite setup -ho"

which msmtp >> /dev/null
if [ $? -ne 0 ]; then
	echo "installing msmtp for email sending"
	tar jxf msmtp-1.4.32.tar.bz2 -C /home/$GITOLITE_USER
	cd /home/$GITOLITE_USER/msmtp-1.4.32
	./configure --prefix=/usr
	make && make install 
	cd -
fi

echo $system_version | grep -q "Ubuntu"
if [ $? -eq 0 ]; then
	cp msmtprc-ubuntu /home/$GITOLITE_USER/.msmtprc
	which mutt >> /dev/null
	if [ $? -ne 0 ] ; then
		apt-get install mutt
	fi
else
	cp msmtprc-centos /home/$GITOLITE_USER/.msmtprc
	which mutt >> /dev/null
	if [ $? -ne 0 ] ; then
		yum install mutt
	fi
fi
chmod 600 /home/$GITOLITE_USER/.msmtprc
chown $GITOLITE_USER.$GITOLITE_USER /home/$GITOLITE_USER/.msmtprc

if ! egrep "#for add Muttr by hover" /etc/Muttrc >> /dev/null; then
	echo "#for add Muttr by hover" >> /etc/Muttrc
	echo "set sendmail=\"/usr/bin/msmtp\""  >> /etc/Muttrc
	echo "set use_from=yes" >> /etc/Muttrc
	echo "set realname=\"Data Report\""  >> /etc/Muttrc
	echo "set editor=\"vim\"" >> /etc/Muttrc
	echo "set from=git@netmoon.cn"  >> /etc/Muttrc
	echo "set envelope_from=yes" >> /etc/Muttrc
fi
echo 
echo "install gitolite successfully..."
