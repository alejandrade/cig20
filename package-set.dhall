let upstream = https://github.com/dfinity/vessel-package-set/releases/download/mo-0.6.21-20220215/package-set.dhall sha256:b46f30e811fe5085741be01e126629c2a55d4c3d6ebf49408fb3b4a98e37589b  
let aviate-labs = https://github.com/aviate-labs/package-set/releases/download/v0.1.7/package-set.dhall sha256:433429e918c292301ae0a7fa2341d463fea2d586c3f9d03209d68ca52e987aa8
let packages = [
  { name = "stable-rbtree"
  , repo = "https://github.com/canscale/StableRBTree"
  , version = "v0.6.0"
  , dependencies = [ "base" ]
  },
  { name = "stable-buffer"
  , repo = "https://github.com/canscale/StableBuffer"
  , version = "v0.2.0"
  , dependencies = [ "base" ]
  },
  { name = "candb"
  , repo = "git@github.com:canscale/CanDB.git"
  , version = "alpha-dev"
  , dependencies = [ "base" ]
  },
  { name = "array"
  , repo = "https://github.com/aviate-labs/array.mo"
  , version = "v0.2.0"
  , dependencies = [ "base" ]
  },
  { name = "asset-storage"
  , repo = "https://github.com/aviate-labs/asset-storage.mo"
  , version = "asset-storage-0.7.0"
  , dependencies = [ "base" ]
  },
  { name = "base"
  , repo = "https://github.com/dfinity/motoko-base"
  , version = "c174fc4bfc0287ccbfbd5a4b55edbc8669e3f2f3" -- Motoko 0.7.0
  , dependencies = [] : List Text
  },
  { name = "bimap"
  , repo = "https://github.com/aviate-labs/bimap.mo"
  , version = "v0.1.1"
  , dependencies = [ "base" ]
  },
  { name = "crypto"
  , repo = "https://github.com/aviate-labs/crypto.mo"
  , version = "v0.3.0"
  , dependencies = [ "base", "encoding" ]
  },
  { name = "encoding"
  , repo = "https://github.com/aviate-labs/encoding.mo"
  , version = "v0.3.2"
  , dependencies = [ "array", "base" ]
  },
  { name = "ext"
  , repo = "https://github.com/aviate-labs/ext.std"
  , version = "v0.2.0"
  , dependencies = [ "array", "base", "encoding", "principal" ]
  },
  { name = "fmt"
  , repo = "https://github.com/aviate-labs/fmt.mo"
  , version = "v0.1.0"
  , dependencies = [ "base" ]
  },
  { name = "hash"
  , repo = "https://github.com/aviate-labs/hash.mo"
  , version = "v0.1.0"
  , dependencies = [ "array", "base" ]
  },
  { name = "io"
  , repo = "https://github.com/aviate-labs/io.mo"
  , version = "v0.3.1"
  , dependencies = [ "base" ]
  },
  { name = "json"
  , repo = "https://github.com/aviate-labs/json.mo"
  , version = "v0.1.2"
  , dependencies = [ "base", "parser-combinators" ]
  },
  { name = "parser-combinators"
  , repo = "https://github.com/aviate-labs/parser-combinators.mo"
  , version = "v0.1.1"
  , dependencies = [ "base" ]
  },
  { name = "principal"
  , repo = "https://github.com/aviate-labs/principal.mo"
  , version = "v0.2.5"
  , dependencies = [ "array", "crypto", "base", "encoding", "hash" ]
  },
  { name = "queue"
  , repo = "https://github.com/aviate-labs/queue.mo"
  , version = "v0.1.1"
  , dependencies = [ "base" ]
  },
  { name = "rand"
  , repo = "https://github.com/aviate-labs/rand.mo"
  , version = "v0.2.2"
  , dependencies = [ "base", "encoding", "io" ]
  },
  { name = "sorted"
  , repo = "https://github.com/aviate-labs/sorted.mo"
  , version = "v0.1.4"
  , dependencies = [ "base" ]
  },
  { name = "stable"
  , repo = "https://github.com/aviate-labs/stable.mo"
  , version = "v0.1.0"
  , dependencies = [ "base" ]
  },
  { name = "ulid"
  , repo = "https://github.com/aviate-labs/ulid.mo"
  , version = "v0.1.2"
  , dependencies = [ "base", "encoding", "io" ]
  },
  { name = "uuid"
  , repo = "https://github.com/aviate-labs/uuid.mo"
  , version = "v0.2.0"
  , dependencies = [ "base", "encoding", "io" ]
  }
]

in  upstream # aviate-labs # packages