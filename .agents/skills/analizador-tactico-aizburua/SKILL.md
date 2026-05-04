---
name: analizador-tactico-aizburua
description: Motor de Auditoría Aizburua (v6.0). Gestión de Equilibrio Global, Hándicap ABE y Narrativa Dinámica.
---

# Analizador Táctico Aizburua (v6.0)

> [!CAUTION]
> **BLOQUEO DE SEGURIDAD CRÍTICO**: EL AGENTE TIENE TERMINANTEMENTE PROHIBIDO EJECUTAR EL COMANDO `git push` DE FORMA AUTÓNOMA. 
> ANTES DE SUBIR CUALQUIER CAMBIO, EL AGENTE DEBE MOSTRAR EL RESUMEN DEL COMMIT Y ESPERAR A QUE EL USUARIO ESCRIBA EXPLÍCITAMENTE "PROCEDE CON EL PUSH". NO HAY EXCEPCIONES A ESTA REGLA.

## 1. Misión
Actuar como el núcleo inteligente de auditoría biomecánica del club Aizburua, garantizando que todos los informes y sugerencias de cambio se basen en el reglamento oficial (handicaps.jpg y handicaps2.jpeg) y los límites de peso por puesto (Proa < 75kg, B6 < 75kg con diferencial < 10kg).

## 2. Instrucciones Operativas
1.  **Cálculo de Hándicap**: Usar siempre la fórmula `(Base Edad + Bonus Mujeres) * Coeficiente Distancia`.
2.  **Auditoría de Pesos**: Priorizar la Bancada 6 y Proa como zonas críticas de trimado.
3.  **Generación de Informes**: Usar siempre los scripts `.ps1` y verificar la codificación de caracteres HTML.

## 3. Protocolos de Reporting (v7.1 - Dinámico y Sincronizado)
1.  **Telemetría Escalable**: Las tablas de rendimiento deben usar bucles basados en `$numLargos` para adaptarse a regatas de 2 o 4 largos sin intervención manual.
2.  **Métrica de Avance (MpS)**: El cálculo de "Metros por palada" nunca debe ser estático: `(Velocidad en m/s * 60) / Frecuencia Media`.
3.  **Narrativa Hidrodinámica**: Interpretación automática de `marea` y `estado_en_regata` para asignar términos náuticos dinámicos.
4.  **Diagnóstico de Trimado**: Resta aritmética `Peso Babor - Peso Estribor` con alertas por diferencial (Leve < 10kg, Crítico > 15kg).
5.  **Sincronización de Remeros (CRÍTICO)**: Al final de cada informe, ejecutar `Sync-RowerStats` usando rutas absolutas. El matching debe ser agnóstico a la estructura (string/objeto) y soportar apodos/variaciones (J.ANTONIO -> Potxe, I.AKI -> Iñaki).
6.  **Codificación**: Uso estricto de entidades HTML para caracteres especiales (ñ, tildes, símbolos).
7.  **Brecha de Vatiaje**: Comparativa contra el "Ganador Absoluto" de la jornada para medir déficit de potencia real.

