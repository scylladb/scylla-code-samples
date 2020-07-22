package handler

import (
	"log"
	"net/http"
	"sort"
	"time"

	"github.com/gocql/gocql"

	"github.com/scylladb/gocqlx/v2/qb"

	"github.com/scylladb/scylla-code-samples/iot-care-pet-example/go/db"
	"github.com/scylladb/scylla-code-samples/iot-care-pet-example/go/model"

	"github.com/go-openapi/runtime/middleware"

	"github.com/scylladb/scylla-code-samples/iot-care-pet-example/go/cmd/server/restapi/operations"
	"github.com/scylladb/gocqlx/v2"
)

// FindSensorAvgBySensorIDAndDay reads sensor day hourly aggregates.
// The functions reads aggregated sensor data from the selected day.
// If the data is missing it aggregates measurements first.
// $ curl http://127.0.0.1:8000/api/sensor/{id}/values/day/{date}
func FindSensorAvgBySensorIDAndDay(ses gocqlx.Session) operations.FindSensorAvgBySensorIDAndDayHandlerFunc {
	return func(req operations.FindSensorAvgBySensorIDAndDayParams) middleware.Responder {
		var data []float32
		var avg []model.SensorAvg
		var day = time.Time(req.Day)

		if day.YearDay() > time.Now().UTC().YearDay() {
			return operations.NewFindOwnerByIDDefault(http.StatusBadRequest)
		}

		// read aggregated data
		err := ses.Query(qb.
			Select(db.SensorAvgMetadata.Name).
			Columns(db.SensorAvgMetadata.Columns...).
			Where(db.TableSensorAvg.PrimaryKeyCmp()[:2]...).ToCql()).
			Bind(req.ID.String(), day).
			SelectRelease(&avg)
		if err != nil {
			log.Println("read sensor avg query: ", err)
			return operations.NewFindOwnerByIDDefault(http.StatusInternalServerError)
		}

		// if aggregated data is not complete - not having 24 hours aggregates - complete it
		if len(avg) < 24 {
			var ok bool
			if avg, ok = aggregate(ses, req, avg); !ok {
				return operations.NewFindOwnerByIDDefault(http.StatusInternalServerError)
			}
		}

		for _, sa := range avg {
			data = append(data, sa.Value)
		}

		return &operations.FindSensorDataBySensorIDAndTimeRangeOK{Payload: data}
	}
}

// aggregate assumes that all the data for the past is present
func aggregate(ses gocqlx.Session, req operations.FindSensorAvgBySensorIDAndDayParams, avg []model.SensorAvg) ([]model.SensorAvg, bool) {
	id := req.ID.String()
	now := time.Now().UTC()
	day := time.Time(req.Day)

	// can't aggregate data for post today's date
	if day.YearDay() > now.YearDay() {
		return nil, false
	}

	// we can start from next missing hour. hours = [0, 23]. len = [0, 24]
	startHour := len(avg)
	startDate := time.Date(day.Year(), day.Month(), day.Day(), startHour, 0, 0, 0, time.UTC)
	endDate := time.Date(day.Year(), day.Month(), day.Day(), 23, 59, 59, 1e9-1, time.UTC)

	timePoints, dataPoints, ok := loadData(ses, id, startDate, endDate)
	if !ok {
		return nil, false
	}

	prevAvgSize := len(avg)
	avg = groupBy(avg, timePoints, dataPoints, startHour, day, now)

	saveAggregate(ses, id, avg, prevAvgSize, startDate, day, now)

	return avg, true
}

func loadData(ses gocqlx.Session, sensorID string, startDate time.Time, endDate time.Time) ([]time.Time, []float32, bool) {
	var timePoints []time.Time
	var dataPoints []float32

	iter := ses.Session.
		Query("SELECT ts, value FROM measurement WHERE sensor_id = ? AND ts >= ? and ts <= ?").
		Bind(sensorID, startDate, endDate).
		Iter()

	for {
		var ts time.Time
		var tp float32
		if !iter.Scan(&ts, &tp) {
			break
		}
		timePoints = append(timePoints, ts)
		dataPoints = append(dataPoints, tp)
	}

	if err := iter.Close(); err != nil {
		log.Println("read sensors data query: ", err)
		return nil, nil, false
	}

	return timePoints, dataPoints, true
}

func groupBy(avg []model.SensorAvg, timePoints []time.Time, dataPoints []float32, startHour int, day, now time.Time) []model.SensorAvg {
	// if it's the same day, we can't aggregate current hour
	sameDate := now.YearDay() == day.YearDay()
	last := now.Hour()

	// aggregate data
	type ag struct {
		value float64
		total uint64
	}
	var m = map[int]ag{}

	for i, tp := range timePoints {
		hour := tp.Hour()

		sa := m[hour]
		sa.total++
		sa.value += float64(dataPoints[i])
		m[hour] = sa
	}

	// ensure data completeness
	for hour := startHour; hour < 24; hour++ {
		if !sameDate || hour <= last {
			if _, ok := m[hour]; !ok {
				m[hour] = ag{}
			}
		}
	}

	// fill the avg
	for hour, item := range m {
		var sa = model.SensorAvg{Hour: hour}
		if item.total > 0 {
			sa.Value = float32(item.value / float64(item.total))
		}
		avg = append(avg, sa)
	}

	// maps are unordered, results must be ordered by hour
	sort.Slice(avg, func(i, j int) bool {
		return avg[i].Hour < avg[j].Hour
	})

	return avg
}

// saveAggregate saves the result monotonically sequentially to the database
func saveAggregate(ses gocqlx.Session, sensorID string, avg []model.SensorAvg, prevAvgSize int, startDate, day, now time.Time) {
	// if it's the same day, we can't aggregate current hour
	sameDate := now.YearDay() == day.YearDay()
	current := now.Hour()

	for i := prevAvgSize; i < len(avg); i++ {
		if sameDate && avg[i].Hour >= current {
			break
		}

		avg[i].SensorID, _ = gocql.ParseUUID(sensorID)
		avg[i].Date = startDate

		if err := db.TableSensorAvg.InsertQuery(ses).BindStruct(avg[i]).ExecRelease(); err != nil {
			log.Println("save sensor aggregate", avg[i], ":", err)
		}
	}
}
