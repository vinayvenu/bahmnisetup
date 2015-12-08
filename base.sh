#!/bin/bash

install_virtual_box_specifics(){
    sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers
    yum -y install gcc make gcc-c++ kernel-devel-`uname -r` perl
}

setup_repos(){
echo "[bahmni]
name            = Bahmni YUM Repository
baseurl         = https://bahmni-repo.twhosted.com/packages/bahmni-release/
enabled         = 1
gpgcheck        = 0" > /etc/yum.repos.d/bahmni.repo

echo "# Enable to use MySQL 5.6
[mysql56-community]
name=MySQL 5.6 Community Server
baseurl=http://repo.mysql.com/yum/mysql-5.6-community/el/6/x86_64
enabled=1
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mysql" > /etc/yum.repos.d/mysql56.repo

    yum install -y wget
    wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm
    rpm -Uvh epel-release-latest-6.noarch.rpm
    #yum -y update
}

install_oracle_jre(){
    #Optional - Ensure that jre is installed
    wget --no-cookies --no-check-certificate --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/7u79-b15/jre-7u79-linux-x64.rpm"
    yum localinstall -y jre-7u79-linux-x64.rpm
}

install_mysql(){
    yum remove -y mysql-libs
    yum clean all
    yum install -y mysql-community-server
    service mysqld start
    mysqladmin -u root password password
}

restore_mysql_database(){
    #Optional Step
    rm -rf mysql_backup.sql.gz mysql_backup.sql
    wget https://github.com/Bhamni/emr-functional-tests/blob/master/dbdump/mysql_backup.sql.gz?raw=true -O mysql_backup.sql.gz
    gzip -d mysql_backup.sql.gz
    mysql -uroot -ppassword < mysql_backup.sql
    echo "FLUSH PRIVILEGES" > flush.sql
    mysql -uroot -ppassword < flush.sql
}

install_pgsql(){
    wget http://yum.postgresql.org/9.2/redhat/rhel-6-x86_64/pgdg-centos92-9.2-7.noarch.rpm
    rpm -ivh pgdg-centos92-9.2-7.noarch.rpm
    yum install -y postgresql92-server
    service postgresql-9.2 initdb
    sed -i 's/peer/trust/g' /var/lib/pgsql/9.2/data/pg_hba.conf
    sed -i 's/ident/trust/g' /var/lib/pgsql/9.2/data/pg_hba.conf
    service postgresql-9.2 start
}

restore_pgsql_db(){
    wget https://github.com/Bhamni/emr-functional-tests/blob/master/dbdump/pgsql_backup.sql.gz?raw=true -O pgsql_backup.sql.gz
    gzip -d pgsql_backup.sql.gz
    psql -Upostgres < pgsql_backup.sql >/dev/null
}

install_bahmni(){
    yum install -y openmrs 
    yum install -y bahmni-emr bahmni-web bahmni-reports bahmni-lab bahmni-lab-connect
}

config_services(){
    chkconfig mysqld on
    chkconfig postgresql-9.2 on
    chkconfig httpd on
    chkconfig openmrs on
    chkconfig bahmni-erp on
    chkconfig bahmni-lab on
}
cleanup(){
    rm jre-7u79-linux-x64.rpm
    rm pgdg-centos92-9.2-7.noarch.rpm
    yum clean packages
}

#install_virtual_box_specifics
echo "Setting up repos"
setup_repos
install_oracle_jre
install_mysql
restore_mysql_database
install_pgsql
restore_pgsql_db
install_bahmni
config_services

chkconfig --add httpd
chkconfig --add openmrs
chkconfig --add bahmni-lab

service httpd start
service openmrs start
service bahmni-lab start
yum install -y tree
mysql -uroot -ppassword openmrs -c "select distinct concat(pn.given_name,' ', pn.family_name) as name,
pi.identifier as identifier,
concat('',p.uuid) as uuid,
concat('',v.uuid) as activeVisitUuid,
IF(va.value_reference = 'Admitted', 'true', 'false') as hasBeenAdmitted
from
 visit v join person_name pn on v.patient_id = pn.person_id and pn.voided = 0 and v.voided=0
  join patient_identifier pi on v.patient_id = pi.patient_id and pi.voided=0
   join person p on p.person_id = v.patient_id  and p.voided=0
    join encounter en on en.visit_id = v.visit_id and en.voided=0
     left outer join location loc on en.location_id = loc.location_id
      join encounter_provider ep on ep.encounter_id = en.encounter_id  and ep.voided=0
       join provider pr on ep.provider_id=pr.provider_id and pr.retired=0
        join person per on pr.person_id=per.person_id and per.voided=0
	 left outer join visit_attribute va on va.visit_id = v.visit_id and va.attribute_type_id = (
	               select visit_attribute_type_id from visit_attribute_type where name='Admission Status'
			                 )
					 where
					  v.date_stopped is null and
					   loc.uuid=${location_uuid}
					    order by en.encounter_datetime desc;"
