package com.scylla.mms.service

import com.outworkers.phantom.dsl._
import com.scylla.mms.cql.MutantsDatabase
import com.scylla.mms.model.Mutant

import scala.concurrent.Future

/**
 * Service class for managing mutant data operations
 * Step 1: Basic read operations only
 */
class MutantsService(db: MutantsDatabase) {
  import db.{session, space}

  def getAll(): Future[List[Mutant]] =
    db.mutants.select.all().fetch()
}
