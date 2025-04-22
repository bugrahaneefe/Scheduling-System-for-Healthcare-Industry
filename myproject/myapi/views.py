# myapi/views.py

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
import json
from .cplex_algorithm import shift_schedule_problem

@csrf_exempt
def generate_schedule(request):
    if request.method == 'POST':
        try:
            input_data = json.loads(request.body.decode('utf-8'))
            duties = shift_schedule_problem(input_data)
            return JsonResponse({'schedule': duties}, status=200)
        except Exception as e:
            return JsonResponse({'error': str(e)}, status=400)
    return JsonResponse({'error': 'Invalid request method'}, status=405)

