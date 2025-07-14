package com.scylla.mms.service

import com.outworkers.phantom.dsl._
import com.scylla.mms.cql.MutantsDatabase
import com.scylla.mms.model.Mutant

import scala.concurrent.Future

/**
 * Service class for managing mutant data operations
 * Step 4: Read, Insert, and Delete operations
 */
class MutantsService(db: MutantsDatabase) {
  import db.{session, space}

  def getAll(): Future[List[Mutant]] =
    db.mutants.select.all().fetch()

  def getByName(firstName: String, lastName: String): Future[Option[Mutant]] =
    db.mutants.select
      .where(_.firstName eqs firstName)
      .and(_.lastName eqs lastName)
      .one()

  def insertMutant(mutant: Mutant): Future[ResultSet] =
    db.mutants.store(mutant).future()

  def deleteMutant(firstName: String, lastName: String): Future[ResultSet] =
    db.mutants.delete
      .where(_.firstName eqs firstName)
      .and(_.lastName eqs lastName)
      .future()
}
