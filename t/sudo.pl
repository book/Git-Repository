#!/usr/bin/env perl

# a tiny fake git wrapper
print "@ARGV" =~ /version/ ? "git version 9.8.7\n" : "@ARGV\n";

