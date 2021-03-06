# This depends on
#   puppetlabs/apt: https://github.com/puppetlabs/puppetlabs-apt
#   example42/puppet-yum: https://github.com/example42/puppet-yum
#   puppetlabs/puppetlabs-apache: https://github.com/puppetlabs/puppetlabs-apache (if apache)

class puphpet::hhvm(
  $nightly = false,
  $webserver
) {

  $real_webserver = $webserver ? {
    'apache'  => 'apache2',
    'httpd'   => 'apache2',
    'apache2' => 'apache2',
    'nginx'   => 'nginx',
    'fpm'     => 'fpm',
    'cgi'     => 'cgi',
    'fcgi'    => 'cgi',
    'fcgid'   => 'cgi',
    undef     => undef,
  }

  if $nightly == true {
    $package_name_base = $puphpet::params::hhvm_package_name_nightly
  } else {
    $package_name_base = $puphpet::params::hhvm_package_name
  }

  if $nightly == true and $::osfamily == 'Redhat' {
    warning('HHVM-nightly is not available for RHEL distros. Falling back to normal release')
  }

  case $::operatingsystem {
    'debian': {
      if $::lsbdistcodename != 'wheezy' {
        fail('Sorry, HHVM currently only works with Debian 7+.')
      }

      include ::puphpet::debian::non_free
    }
    'ubuntu': {
      if ! ($lsbdistcodename in ['precise', 'raring', 'trusty']) {
        fail('Sorry, HHVM currently only works with Ubuntu 12.04, 13.10 and 14.04.')
      }

      apt::key { '5D50B6BA': key_server => 'hkp://keyserver.ubuntu.com:80' }

      if $lsbdistcodename in ['lucid', 'precise'] {
        apt::ppa { 'ppa:mapnik/boost': require => Apt::Key['5D50B6BA'], options => '' }
      }
    }
    'centos': {
      $jemalloc_url = 'http://files.puphpet.com/centos6/jemalloc-3.6.0-1.el6.x86_64.rpm'
      $jemalloc_download_location = '/.puphpet-stuff/jemalloc-3.6.0-1.el6.x86_64.rpm'

      $require = defined(Class['my_fw::post']) ? {
        true    => Class['my_fw::post'],
        default => [],
      }

      exec { "download jemalloc to ${download_location}":
        creates => $download_location,
        command => "wget --quiet --tries=5 --connect-timeout=10 -O '${jemalloc_download_location}' '${jemalloc_url}'",
        timeout => 30,
        path    => '/usr/bin',
        require => $require
      }

      package { 'jemalloc':
        ensure   => latest,
        provider => yum,
        source   => $download_location,
        require  => Exec["download jemalloc to ${download_location}"],
      }

      yum::managed_yumrepo { 'hop5':
        descr    => 'hop5 repository',
        baseurl  => 'http://www.hop5.in/yum/el6/',
        gpgkey   => 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-HOP5',
        enabled  => 1,
        gpgcheck => 0,
        priority => 1,
      }
    }
  }
  if $real_webserver == 'apache2' {
    include ::puphpet::apache::fpm
  }

  $os = downcase($::operatingsystem)

  case $::osfamily {
    'debian': {
      apt::key { 'hhvm':
        key        => '16d09fb4',
        key_source => 'http://dl.hhvm.com/conf/hhvm.gpg.key',
      }

      apt::source { 'hhvm':
        location          => "http://dl.hhvm.com/${os}",
        repos             => 'main',
        required_packages => 'debian-keyring debian-archive-keyring',
        include_src       => false,
        require           => Apt::Key['hhvm']
      }
    }
  }

  if ! defined(Package[$package_name_base]) {
    package { $package_name_base:
      ensure => present
    }
  }

}
