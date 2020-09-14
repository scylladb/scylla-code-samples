package com.scylla.mms.cql

import com.outworkers.phantom.dsl._

class MutantsDatabase(override val connector: CassandraConnection)
    extends Database[MutantsDatabase](connector) {
  object mutants extends Mutants with Connector
}
