require 'mkmf'

dir_config("dbm")

if dblib = with_config("dbm-type", nil)
  dblib = dblib.split(/[ ,]+/)
else
  dblib = %w(db db2 db1 db5 db4 db3 dbm gdbm gdbm_compat qdbm)
end

headers = {
  "db" => ["db.h"],
  "db1" => ["db1/ndbm.h", "db1.h", "ndbm.h"],
  "db2" => ["db2/db.h", "db2.h", "db.h"],
  "db3" => ["db3/db.h", "db3.h", "db.h"],
  "db4" => ["db4/db.h", "db4.h", "db.h"],
  "db5" => ["db5/db.h", "db5.h", "db.h"],
  "dbm" => ["ndbm.h"],
  "gdbm" => ["gdbm-ndbm.h", "ndbm.h", "gdbm/ndbm.h"],
  "gdbm_compat" => ["gdbm-ndbm.h", "ndbm.h", "gdbm/ndbm.h"], # ndbm compatibility routines are extracted to libgdbm_compat since gdbm-1.8.1.
  "qdbm" => ["relic.h", "qdbm/relic.h"],
}

class << headers
  attr_accessor :found
  attr_accessor :defs
end
headers.found = []
headers.defs = nil

def headers.db_check(db)
  have_gdbm = false
  hsearch = nil

  case db
  when /^db[2-5]?$/
    hsearch = "-DDB_DBM_HSEARCH"
  when "gdbm"
    have_gdbm = true
  when "gdbm_compat"
    have_gdbm = true
    have_library("gdbm") or return false
  end

  if (hdr = self.fetch(db, ["ndbm.h"]).find {|h| have_type("DBM", h, hsearch)} or
      hdr = self.fetch(db, ["ndbm.h"]).find {|h| have_type("DBM", ["db.h", h], hsearch)}) and
     (have_library(db, 'dbm_open("", 0, 0)', hdr, hsearch) || have_func('dbm_open("", 0, 0)', hdr, hsearch))
    have_func('dbm_clearerr((DBM *)0)', hdr, hsearch) unless have_gdbm
    if hsearch
      $defs << hsearch
      @defs = hsearch
    end
    $defs << '-DDBM_HDR="<'+hdr+'>"'
    @found << hdr
    true
  else
    false
  end
end

if dblib.any? {|db| headers.db_check(db)}
  have_header("cdefs.h")
  have_header("sys/cdefs.h")
  have_func("dbm_pagfno((DBM *)0)", headers.found, headers.defs)
  have_func("dbm_dirfno((DBM *)0)", headers.found, headers.defs)
  type = checking_for "sizeof(datum.dsize)", STRING_OR_FAILED_FORMAT do
    pre = headers.found + [["static datum conftest_key;"]]
    %w[int long LONG_LONG].find do |t|
      try_static_assert("sizeof(conftest_key.dsize) <= sizeof(#{t})", pre, headers.defs)
    end
  end
  $defs << "-DSIZEOF_DSIZE=SIZEOF_"+type.tr_cpp if type
  create_makefile("dbm")
end
