use IRC::Log:ver<0.0.26+>:auth<zef:lizmat>;

#- subroutine ------------------------------------------------------------------
my sub channel-id(str $channel --> Str:D) {
    run-query("SELECT id FROM ilbot_channel WHERE channel = '#$channel'").chomp
}

my sub run-query(str $query --> Str:D) {
    my $proc := run "mariadb", "perlgeek", "--skip-column-names", :in, :out;
    my $in := $proc.in;
    $in.print($query);
    $in.close;
    if $proc.exitcode -> $code {
        die "'$query' failed: $code";
    }
    else {
        $proc.out.slurp
    }
}

my sub log-for-channel-date(str $channel, str $date --> Str:D) {
    if channel-id($channel) -> $id {
        if run-query(
          "SELECT id FROM ilbot_day WHERE channel = $id AND day = '$date'"
        ) -> $day {
            return run-query(
              "SELECT timestamp,nick,line FROM ilbot_lines WHERE day = $day"
            )
        }
    }
    ""
}

my sub IO-for-channel-date(
  IO() $base, Str:D $channel, Str() $date
--> IO::Path:D) {
    $base.add($channel).add($date.substr(0,4)).add($date)
}

#- IRC::Log::Perlgeek ----------------------------------------------------------
class IRC::Log::Perlgeek:ver<0.0.2>:auth<zef:lizmat> does IRC::Log {
    has $.channel;

    method !problem(Str:D $line, Int:D $linenr, Str:D $reason --> Nil) {
        $!problems.push: "Line $linenr: $reason" => $line;
    }

    multi method new(IRC::Log::Perlgeek: Str:D :$channel!, Str() :$date!) {
        self.new(
          log-for-channel-date($channel, $date), $date
        )!SET-SELF($channel)
    }
    method !SET-SELF($!channel) { self }

#- class methods ---------------------------------------------------------------
    method channels(IRC::Log::Perlgeek:U: --> List:D) {
        run-query(
          "SELECT channel FROM ilbot_channel ORDER BY channel"
        ).lines.map(*.substr(1)).List
    }

    method dates-for-channel(IRC::Log::Perlgeek:U: str $channel --> List:D) {
        if channel-id($channel) -> $id {
            run-query(
              "SELECT day FROM ilbot_day WHERE channel = $id ORDER BY day"
            ).lines.List
        }
        else {
            ()
        }
    }

#- instance methods ------------------------------------------------------------
    method save-as-colabti(IO() $base = ".") {
        my $date := self.date;
        my $dir  := $base.add($!channel).add($date.substr(0,4));
        $dir.mkdir;

        $dir.add($date).spurt(self.Str)
    }

#- method required by role -----------------------------------------------------
    method parse-log(IRC::Log::Perlgeek:D:
      str $text,
          $last-hour               is raw,
          $last-minute             is raw,
          $ordinal                 is raw,
          $linenr                  is raw,
          $nr-control-entries      is raw,
          $nr-conversation-entries is raw,
    --> Nil) is implementation-detail {

        my str $last-line = "";
        for $text.lines.map({
            ++$linenr;
            if .chars && $_ ne $last-line {
                $last-line = $_;
                .split("\t").List
            }
        }) -> ($epoch, $nick, $text) {

            my $datetime := DateTime.new($epoch.Int);
            my int $hour   = $datetime.hour;
            my int $minute = $datetime.minute;

            if $minute == $last-minute && $hour == $last-hour {
                ++$ordinal;
            }
            else {
                $last-hour   = $hour;
                $last-minute = $minute;
                $ordinal     = 0;
            }

            if $nick eq 'NULL' {
                my @words = $text.words;
                if @words[1] eq 'joined' {
                    IRC::Log::Joined.new(
                      :log(self), :$hour, :$minute, :$ordinal, :nick(@words[0])
                    );
                    ++$nr-control-entries;
                }
                elsif @words[1] eq 'left' | 'quit' {
                    IRC::Log::Left.new(
                      :log(self), :$hour, :$minute, :$ordinal, :nick(@words[0])
                    );
                    ++$nr-control-entries;
                }
                elsif $text.starts-with("Topic for #", :ignorecase) {
                    with $text.index("is now ") -> $index {
                        self.last-topic-change = IRC::Log::Topic.new(
                          :log(self), :$hour, :$minute, :$ordinal,
                          :nick<moderator>, :text($text.substr($index + 7))
                        );
                        ++$nr-control-entries;
                        ++$nr-conversation-entries;
                    }
                }
                orwith $text.index(' the topic to ') -> $index {
                    with $text.index("is now ") -> $index {
                        self.last-topic-change = IRC::Log::Topic.new(
                          :log(self), :$hour, :$minute, :$ordinal,
                          :nick(@words[0]), :text($text.substr($index + 21))
                        );
                        ++$nr-control-entries;
                        ++$nr-conversation-entries;
                    }
                }
                elsif $text.contains(
                  ' is now known as '
                  | ' changed the nick to '
                  | ' changed their nick to '
                ) {
                    IRC::Log::Nick-Change.new(
                      :log(self), :$hour, :$minute, :$ordinal,
                      :nick(@words.head), :new-nick(@words.tail)
                    );
                    ++$nr-control-entries;
                }
                elsif $text.starts-with('was kicked by ') {
                    my $kickee := @words[0];
                    my $nick   := @words[4].chop;  # lose the colon
                    IRC::Log::Kick.new(
                      :log(self), :$hour, :$minute, :$ordinal,
                      :nick(@words[4].chop), :kickee(@words[0]),
                      :spec(@words.skip(5).join(" "))
                    );
                    ++$nr-control-entries;
                }
                elsif @words[1] eq 'sets' && @words[2] eq 'mode:' {
                    my $flags     := @words[3];
                    my @nick-names = @words.skip(4);
                    IRC::Log::Mode.new:
                      :log(self), :$hour, :$minute, :$ordinal,
                      :nick(@words[0]), :$flags, :@nick-names;
                    ++$nr-control-entries;
                }
                elsif @words[2] eq 'logging' {
                    # logger starting / stopping, no class for this
                }
                else {
                    self!problem($text, $linenr,
                      'unclear control message');
                }
            }
            elsif $nick.starts-with('* ') {
                IRC::Log::Self-Reference.new(
                  :log(self), :$hour, :$minute, :$ordinal,
                  :nick($nick.substr(2)), :$text
                );
                ++$nr-conversation-entries;
            }
            else {
                IRC::Log::Message.new(
                  :log(self), :$hour, :$minute, :$ordinal, :$nick, :$text
                );
                ++$nr-conversation-entries;
            }
        }
    }
}

sub EXPORT() { IRC::Log::Perlgeek.EXPORT }

# vim: expandtab shiftwidth=4
