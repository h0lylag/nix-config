final: prev: {
  pgadmin4 = prev.pgadmin4.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      # Psycopg 3.3.5 changed _py_codecs from a dict to a tuple.
      # Backport the upstream encoding fix without its dependency updates.
      # Remove once nixpkgs includes this fix in pgAdmin.
      (final.fetchpatch {
        name = "pgadmin-psycopg-3.3.5.patch";
        url = "https://github.com/pgadmin-org/pgadmin4/commit/bd7cde585122337b299cfd748ae991081eb6bef8.patch";
        includes = [ "web/pgadmin/utils/driver/psycopg3/encoding.py" ];
        hash = "sha256-wxcKq9gJ69f6/DyGqVxHtmmvAnoDmtfzojfhtrSae3U=";
      })
    ];
  });
}
