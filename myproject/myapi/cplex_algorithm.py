# myapi/cplex_algorithm.py

import datetime
import numpy as np
import scipy.sparse as sp

import cplex as cp

def list_days_between(start_date: datetime.date, end_date: datetime.date):
    days = []
    current_date = start_date
    day_counter = 1

    while current_date <= end_date:
        day_info = {
            "date": current_date.strftime("%-d %B %Y %A"),
            "day": day_counter
        }
        days.append(day_info)
        current_date += datetime.timedelta(days=1)
        day_counter += 1

    return days


def mixed_integer_linear_programming(direction, A, senses, b, c, l, u, types, names):
    prob = cp.Cplex()

    prob.variables.add(obj=c.tolist(), lb=l.tolist(), ub=u.tolist(), types=types.tolist(), names=names.tolist())

    if direction == "maximize":
        prob.objective.set_sense(prob.objective.sense.maximize)
    else:
        prob.objective.set_sense(prob.objective.sense.minimize)

    prob.linear_constraints.add(senses=senses.tolist(), rhs=b.tolist())

    row_indices, col_indices = A.nonzero()
    prob.linear_constraints.set_coefficients(zip(row_indices.tolist(),
                                                 col_indices.tolist(),
                                                 A.data.tolist()))

    prob.solve()
    print(prob.write_as_string())

    print(prob.solution.get_status())
    print(prob.solution.status[prob.solution.get_status()])

    x_star = prob.solution.get_values()
    obj_star = prob.solution.get_objective_value()

    return (x_star, obj_star)


def shift_schedule_problem(input_data):
    firstDay = datetime.datetime.strptime(input_data['firstDay'], "%Y-%m-%d").date()
    lastDay = datetime.datetime.strptime(input_data['lastDay'], "%Y-%m-%d").date()
    IDs = np.array(input_data['doctors'])
    num_shifts = np.array(input_data['numShifts'])
    required_doctors = np.array(input_data['dailyShifts'])
    availabilities = np.array(input_data['availabilityMatrix'])

    days = list_days_between(firstDay, lastDay)

    num_doctors = np.size(IDs)
    num_days = np.size(days)
    
    names = np.array(["x_{}_{}".format(id, day['day']) for id in IDs for day in days])
    num_variables = np.size(names)

    c = availabilities.flatten()
    #önce min requiredlar G, sonra num shiftsler E, art arda günler L
    senses = np.concatenate((np.repeat("G", num_days), np.repeat("E", num_doctors), np.repeat("L", (num_days-1)*num_doctors)))
    b = np.concatenate((required_doctors, num_shifts, np.repeat(1, (num_days-1)*num_doctors)))
    l = np.repeat(0, num_variables)
    u = np.repeat(1, num_variables)
    types = np.repeat("B", num_variables)

    aij = np.repeat(1, (2*num_days*num_doctors)+(2*(num_days-1)*num_doctors))
    row = np.concatenate((np.repeat(range(num_days), num_doctors), num_days + np.repeat(range(num_doctors), num_days),
                          num_days + num_doctors + np.repeat(range((num_days-1)*num_doctors), 2)))
    
    arr = np.array([])
    for i in range(num_doctors):
       temp = (i * num_days) + np.concatenate((np.array([0]), np.repeat(range(1, num_days-1), 2), np.array([num_days-1])))
       arr = np.concatenate((arr, temp))
        
    col = np.concatenate((np.reshape(range(num_variables), (num_days, num_doctors), order = "F").reshape((num_variables,)),
                          range(num_variables), arr)).astype(int)
    A= sp.csr_matrix((aij, (row,col)), shape= (np.size(senses), num_variables))

    x_star, obj_star = mixed_integer_linear_programming("maximize", A, senses, b, c, l, u, types, names)
            
    duties = {day['date']: [] for day in days}
    
    for day in days:
        first = day['day'] - 1
        for doc in range(num_doctors):
            var_indices = first + num_days*doc
            if(x_star[var_indices] >= 1):
                duties[day['date']].append(IDs[doc])
    
    return duties
