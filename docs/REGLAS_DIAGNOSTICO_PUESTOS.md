# Protocolo de Diagnóstico Táctico Aizburua v6.8

Este documento detalla las reglas biomecánicas y de equilibrio que el motor táctico aplica automáticamente para generar los informes de regata y las recomendaciones de alineación.

## 1. Reglas por Posición (Biotipos)

El sistema evalúa a cada remero según el puesto que ocupa en la alineación, no solo por su capacidad individual.

### Proa (Puesto de Proa)
*   **Función:** Estratega de paso de ola y navegación técnica.
*   **Límite de Peso:** **75 kg**.
*   **Alerta:** Si el remero en proa supera los 75kg, el sistema emite una alerta de **Riesgo de Trimado Longitudinal** (hundimiento de punta), lo que dificulta que el bote "salte" la ola y aumenta el rozamiento.

### Bloque de Popa (Bancadas 1 y 2)
*   **Función:** Potencia de salida y control de inercia en ciaboga.
*   **Límite de Peso:** **85 kg** (en Bancada 1).
*   **Alerta:** Si el remero en la Bancada 1 supera los 85kg, se evalúa el impacto en el hundimiento de popa durante la fase de tracción máxima.

### Motor Central (Bancadas 3, 4 y 5)
*   **Función:** Núcleo de tracción pura y vataje constante.
*   **Límite de Edad:** **65 años**.
*   **Alerta:** El sistema alerta si hay remeros de más de 65 años en el "Motor Central", sugiriendo posiciones de mayor componente técnica (Proa/Popa) para preservar la explosividad del bloque motor.

### Bancada 6 (Apoyo y Estabilización)
*   **Función:** Nexo de unión entre el bloque motor y la vanguardia. Actúa como el amortiguador lateral del bote.
*   **Límite de Peso Individual:** **75 kg** (Siguiendo protocolo v4.6).
*   **Criterio de Peso Lateral:** Se vigila que el diferencial entre Babor y Estribor en esta línea no supere los **10 kg**. 
*   **Alerta:** Debido a su proximidad a la proa, cualquier desequilibrio en la B6 se amplifica en la punta. El sistema lanza una alerta si un remero supera los 75kg o si la asimetría entre bandas supera los 10kg.

---

## 2. Métricas de Rendimiento (Calidad Biomecánica)

Además de las alertas de peso, el sistema cruza estos datos para optimizar la navegación:

### Altura (Optimización de Palanca)
*   **Uso:** El sistema utiliza la altura para calcular el **Arco de Palada** teórico. 
*   **Criterio:** Se prioriza a los remeros de mayor estatura en el **bloque central (3-4-5)**. Una mayor altura permite una palada más larga y eficiente, ideal para desplazar la masa de agua en la fase de tracción máxima.

### Experiencia (Eficiencia y Temple)
*   **Uso:** Define el **Coeficiente de Técnica**.
*   **Criterio:** El sistema busca "Núcleos de Experiencia" en los extremos del bote. Los remeros con mayor historial de boga son situados preferentemente en la **Bancada 1 (Popa)** y **Bancada 6/Proa** para asegurar un ritmo estable y una técnica depurada en las maniobras de ciaboga.

### Edad (Gestión de Energía)
*   **Uso:** Predicción de **Vaciado Muscular**.
*   **Criterio:** El sistema analiza la edad media de los bloques. Si un bloque (ej. Proa) es significativamente más veterano que el de Popa, el sistema advierte sobre una posible descompensación de ritmo en los metros finales de la regata por fatiga acumulada.

---

## 2. Reglas de Equilibrio Estructural (Trimado)

### Desequilibrio Lateral (Babor vs Estribor)
*   **Métrica:** Diferencia de peso total entre las bandas de babor y estribor.
*   **Límite Crítico:** **15 kg**.
*   **Alerta:** Si una banda pesa >15kg más que la otra, el sistema genera una **Alerta de Escora**, advirtiendo que el patrón deberá compensar con el timón, lo que genera un "freno" constante por hidrodinámica.

### Equilibrio por Bancada
*   Se evalúa la diferencia de peso individual entre los dos remeros de una misma bancada. Si la asimetría es extrema, se sugiere un intercambio de bandas dentro de la misma línea.

---

## 3. Protocolo de Hándicap ABE (Auditoría)

El cálculo se realiza estrictamente en este orden jerárquico:

1.  **Base por Edad:** Se calcula la edad media de los 14 tripulantes (redondeando hacia abajo, ej: 53.9 -> 53). Se consultan los segundos correspondientes en la tabla `handicaps.jpg`.
2.  **Bonificación de Género:** Se suman **+5 segundos planos** por cada mujer de 45 años o más a bordo.
3.  **Escalado por Distancia:** La suma anterior `(Base + Bonus)` se multiplica por el **Coeficiente de Tramo** definido en `handicaps2.jpeg` según la distancia oficial de la regata.

---

## 4. Notas de Implementación
*   **Agnosticismo de Nombres:** El sistema aplica estas reglas al *puesto* del JSON. Si cambias al remero, la regla se recalcula automáticamente con los datos de su ficha personal.
*   **Soberanía del Dato Oficial:** Se prioriza siempre la distancia oficial de la regata sobre la distancia GPS para evitar discrepancias con el comité.
