[![Actions Status](https://github.com/lizmat/IRC-Log-Perlgeek/actions/workflows/linux.yml/badge.svg)](https://github.com/lizmat/IRC-Log-Perlgeek/actions) [![Actions Status](https://github.com/lizmat/IRC-Log-Perlgeek/actions/workflows/macos.yml/badge.svg)](https://github.com/lizmat/IRC-Log-Perlgeek/actions) [![Actions Status](https://github.com/lizmat/IRC-Log-Perlgeek/actions/workflows/windows.yml/badge.svg)](https://github.com/lizmat/IRC-Log-Perlgeek/actions)

NAME
====

IRC::Log::Perlgeek - interface to IRC logs from irclog.perlgeek.de

SYNOPSIS
========

```raku
use IRC::Log::Perlgeek;

my $log = IRC::Log::Perlgeek.new(:$channel, :$date);

say "Logs from $log.date()";
say $log;
```

DESCRIPTION
===========

The `IRC::Log::Perlgeek` distribution provides the logic to read the "perlgeek" database that was the data source of the "irclog.perlgeek.de" website, and produce an `IRC::Log` compatible object for a given channel and date.

ADDITIONAL INSTANCE METHODS
===========================

save-as-colabti
---------------

```raku
my $log = IRC::Log::Perlgeek.new(:$channel, :$date);
$log.save-as-colabti;

$log.save-as-colabti("IRC-logs");
```

The `save-as-colabti` method will save the log in a `IRC::Log::Colabti` compatible format in the correct location to be compatible with the logic of the `IRC::Channel::Log` distribution.

By default the file will be stored from the current directory onward, A path of `IO::Path` object to serve as the base, can be specified as a positional argument.

ADDITIONAL CLASS METHODS
========================

channels
--------

```raku
.say for IRC::Log::Perlgeek.channels;
```

The `channels` class method returns a `List` of channel names that are available in the "perlgeek" database.

dates-for-channel
-----------------

```raku
.say for IRC::Log::Perlgeek.dates-for-channel("parrot");
```

The `dates-for-channel` class method returns a `List` of dates as strings in YYYY-MM-DD format that are available in the "perlgeek" database for the specified channel name.

SCRIPTS
=======

perlgeek-import
---------------

    $ perlgeek-import parrot

The `perlgeek-import` script will import the logs of the given channel name into the current directory. A second argument can be specified to indicate the directory in which the logs should be stored.

By default progress will be shown. This can be inhibited by specifying the `--/verbose` argument.

If no channel name has been specified, an overview of the available channels will be shown:

    $ perlgeek-import
    #shibboleth: 2014-01-13 - 2014-01-14 (   2 days)
        6macros: 2015-02-24 - 2018-06-04 (1174 days)
        askriba: 2016-08-22 - 2018-06-04 ( 601 days)
      bioclipse: 2007-07-31 - 2015-11-12 (3002 days)
    ...

PREREQUISITES
=============

The functionality of this distribution assumes the command-line interface to the MariaDB servers is installed as "mariadb", and that the Perlgeek database is loaded in the server instance by the name "perlgeek".

AUTHOR
======

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/IRC-Log-Perlgeek . Comments and Pull Requests are welcome.

If you like this module, or what I'm doing more generally, committing to a [small sponsorship](https://github.com/sponsors/lizmat/) would mean a great deal to me!

COPYRIGHT AND LICENSE
=====================

Copyright 2026 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

