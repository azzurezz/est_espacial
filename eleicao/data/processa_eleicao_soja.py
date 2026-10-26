#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script: processa_eleicao_soja.py
Objetivo: 
  - Extrai com precisão todas as seções da Tabela 1612 (soja_mg_municipios.csv):
    Área plantada (ha), Quantidade produzida (ton), Valor da produção (mil R$), etc.
  - Extrai os votos oficiais de PRESIDENTE no 1º Turno (04/10/2026) em MG
    para Flávio Bolsonaro (22) e Lula (13).
  - Gera as bases processadas, GeoJSON enriquecido e Matriz W de vizinhança.
"""

import csv
import json
import unicodedata
import os
import math

def clean_str(s):
    if not s:
        return ""
    s = unicodedata.normalize('NFD', s)
    return ''.join(c for c in s if unicodedata.category(c) != 'Mn').strip().upper()

def calcular_centroide(geometry):
    coords_list = []
    gtype = geometry.get('type')
    coords = geometry.get('coordinates', [])
    
    if gtype == 'Polygon':
        coords_list.append(coords[0])
    elif gtype == 'MultiPolygon':
        for poly in coords:
            coords_list.append(poly[0])
            
    total_area = 0.0
    cx_num = 0.0
    cy_num = 0.0
    all_lons = []
    all_lats = []
    
    for ring in coords_list:
        n = len(ring)
        if n < 3:
            continue
        area_ring = 0.0
        cx_ring = 0.0
        cy_ring = 0.0
        for i in range(n - 1):
            x0, y0 = ring[i][0], ring[i][1]
            x1, y1 = ring[i+1][0], ring[i+1][1]
            all_lons.extend([x0, x1])
            all_lats.extend([y0, y1])
            cross = (x0 * y1 - x1 * y0)
            area_ring += cross
            cx_ring += (x0 + x1) * cross
            cy_ring += (y0 + y1) * cross
        area_ring = area_ring * 0.5
        if abs(area_ring) > 1e-12:
            total_area += abs(area_ring)
            cx_num += (cx_ring / (6.0 * area_ring)) * abs(area_ring)
            cy_num += (cy_ring / (6.0 * area_ring)) * abs(area_ring)
            
    if total_area > 0:
        return cx_num / total_area, cy_num / total_area
    else:
        return sum(all_lons) / len(all_lons), sum(all_lats) / len(all_lats)

def main():
    print("Iniciando processamento detalhado da Tabela 1612 e Votação Presidencial...")

    # 1. Carregar lista oficial de municípios IBGE MG
    with open('eleicao/data/raw/ibge_mg_municipios.json', encoding='utf-8') as f:
        ibge_list = json.load(f)

    ibge_map = {}
    for m in ibge_list:
        cname = clean_str(m['nome'])
        ibge_map[cname] = {
            'cod_ibge': str(m['id']),
            'nome_ibge': m['nome'],
            'mesorregiao': m['microrregiao']['mesorregiao']['nome'],
            'microrregiao': m['microrregiao']['nome']
        }
    print(f"1. Mapeados {len(ibge_map)} municípios IBGE de MG.")

    # 2. Extrair variáveis completas da Tabela 1612 (soja_mg_municipios.csv)
    tabela_vars = {}
    current_var = None

    with open('eleicao/soja_mg_municipios.csv', encoding='utf-8-sig') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            if line.startswith('\"Variável - '):
                current_var = line.replace('\"Variável - ', '').replace('\"', '').strip()
                if current_var not in tabela_vars:
                    tabela_vars[current_var] = {}
                continue
            parts = line.split(';')
            if len(parts) >= 2 and current_var:
                col0 = parts[0].replace('\"', '').strip()
                val_str = parts[1].replace('\"', '').strip()
                if col0.endswith('(MG)'):
                    mun = clean_str(col0[:-4].strip())
                    if val_str in ['-', '...', '..', '', 'X']:
                        val = 0.0
                    else:
                        try:
                            val = float(val_str.replace(',', '.'))
                        except ValueError:
                            val = 0.0
                    tabela_vars[current_var][mun] = val

    var_area_ha = tabela_vars.get('Área plantada (Hectares)', {})
    var_area_pct = tabela_vars.get('Área plantada - percentual do total geral', {})
    var_prod_ton = tabela_vars.get('Quantidade produzida (Toneladas)', {})
    var_valor_mil = tabela_vars.get('Valor da produção (Mil Reais)', {})
    var_rend_kg = tabela_vars.get('Rendimento médio da produção (Quilogramas por Hectare)', {})

    print(f"2. Tabela 1612 processada:")
    print(f"   - Área plantada total: {sum(var_area_ha.values()):,.0f} hectares (Máx: {max(var_area_ha.values()):,.0f} ha)")
    print(f"   - Produção total: {sum(var_prod_ton.values()):,.0f} toneladas (Máx: {max(var_prod_ton.values()):,.0f} ton)")
    print(f"   - Valor da produção: R$ {sum(var_valor_mil.values()):,.0f} mil")

    # 3. Carregar dados de PIB e Agropecuária municipal (IBGE 5938)
    pib_data = {}
    if os.path.exists('eleicao/data/raw/ibge_pib_agro_mg.json'):
        with open('eleicao/data/raw/ibge_pib_agro_mg.json', encoding='utf-8') as f:
            pib_raw = json.load(f)
        for row in pib_raw[1:]:
            cod = row['D1C']
            var = row['D2C']
            val_str = row['V']
            val = float(val_str.replace(',', '.')) if val_str not in ['...', '-', '..', 'X'] else 0.0
            if cod not in pib_data:
                pib_data[cod] = {'pib_total_mil': 0.0, 'pib_agro_mil': 0.0, 'share_agro_pct': 0.0}
            if var == '37':
                pib_data[cod]['pib_total_mil'] = val
            elif var == '513':
                pib_data[cod]['pib_agro_mil'] = val
            elif var == '516':
                pib_data[cod]['share_agro_pct'] = val

    # 4. Carregar votos processados de Presidente no 1º Turno (2026)
    # Se o CSV processado já tiver os votos de Presidente, ler dele; se não, ler de dados_eleicao_soja_mg.csv
    dados_votos = {}
    with open('eleicao/data/processed/dados_eleicao_soja_mg.csv', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            mun = clean_str(row['municipio'])
            dados_votos[mun] = {
                'votos_validos_total': int(float(row['votos_validos_total'])),
                'votos_flavio_bolsonaro': int(float(row['votos_flavio_bolsonaro'])),
                'pct_votos_flavio_bolsonaro': float(row['pct_votos_flavio_bolsonaro']),
                'votos_lula': int(float(row['votos_lula'])),
                'pct_votos_lula': float(row['pct_votos_lula'])
            }

    # 5. Carregar malha espacial e extrair centroides
    with open('eleicao/data/raw/mg_municipios.geojson', encoding='utf-8') as f:
        geojson_data = json.load(f)

    centroides = {}
    for feat in geojson_data['features']:
        cod = feat['properties']['codarea']
        c_lon, c_lat = calcular_centroide(feat['geometry'])
        centroides[cod] = {'lon': round(c_lon, 5), 'lat': round(c_lat, 5)}

    # 6. Unificar base de dados consolidada
    linhas = []
    for mun_clean, info_ibge in ibge_map.items():
        cod_ibge = info_ibge['cod_ibge']
        soja_area = var_area_ha.get(mun_clean, 0.0)
        soja_ton = var_prod_ton.get(mun_clean, 0.0)
        soja_valor = var_valor_mil.get(mun_clean, 0.0)
        soja_pct = var_area_pct.get(mun_clean, 0.0)
        pib = pib_data.get(cod_ibge, {'pib_total_mil': 0.0, 'pib_agro_mil': 0.0, 'share_agro_pct': 0.0})
        voto = dados_votos.get(mun_clean, {
            'votos_validos_total': 0, 'votos_flavio_bolsonaro': 0,
            'pct_votos_flavio_bolsonaro': 0.0, 'votos_lula': 0, 'pct_votos_lula': 0.0
        })
        cent = centroides.get(cod_ibge, {'lon': 0.0, 'lat': 0.0})

        linhas.append({
            'cod_ibge': cod_ibge,
            'municipio': info_ibge['nome_ibge'],
            'mesorregiao': info_ibge['mesorregiao'],
            'microrregiao': info_ibge['microrregiao'],
            'centroide_lon': cent['lon'],
            'centroide_lat': cent['lat'],
            'votos_validos_total': voto['votos_validos_total'],
            'votos_flavio_bolsonaro': voto['votos_flavio_bolsonaro'],
            'pct_votos_flavio_bolsonaro': voto['pct_votos_flavio_bolsonaro'],
            'votos_lula': voto['votos_lula'],
            'pct_votos_lula': voto['pct_votos_lula'],
            'soja_area_plantada_ha': round(soja_area, 1),
            'soja_producao_ton': round(soja_ton, 1),
            'soja_valor_mil_reais': round(soja_valor, 1),
            'soja_area_pct': round(soja_pct, 2),
            'tem_soja': 1 if soja_area > 0 else 0,
            'pib_total_mil': round(pib['pib_total_mil'], 1),
            'pib_agro_mil': round(pib['pib_agro_mil'], 1),
            'share_agro_pct': round(pib['share_agro_pct'], 2)
        })

    linhas.sort(key=lambda x: x['cod_ibge'])

    # Salvar CSV final
    csv_out = 'eleicao/data/processed/dados_eleicao_soja_mg.csv'
    with open(csv_out, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=list(linhas[0].keys()))
        writer.writeheader()
        writer.writerows(linhas)
    print(f"3. Base final unificada salva em: {csv_out}")

    # Salvar GeoJSON enriquecido
    lookup = {row['cod_ibge']: row for row in linhas}
    for feat in geojson_data['features']:
        cod = feat['properties']['codarea']
        if cod in lookup:
            r = lookup[cod]
            feat['properties'] = {
                'cod_ibge': cod,
                'municipio': r['municipio'],
                'mesorregiao': r['mesorregiao'],
                'votos_flavio_bolsonaro': r['votos_flavio_bolsonaro'],
                'pct_votos_flavio_bolsonaro': r['pct_votos_flavio_bolsonaro'],
                'pct_votos_lula': r['pct_votos_lula'],
                'votos_validos': r['votos_validos_total'],
                'soja_area_plantada_ha': r['soja_area_plantada_ha'],
                'soja_producao_ton': r['soja_producao_ton'],
                'tem_soja': r['tem_soja'],
                'share_agro_pct': r['share_agro_pct'],
                'pib_total_mil': r['pib_total_mil']
            }
    geojson_out = 'eleicao/data/processed/mg_municipios_completo.geojson'
    with open(geojson_out, 'w', encoding='utf-8') as f:
        json.dump(geojson_data, f, ensure_ascii=False)
    print(f"4. GeoJSON enriquecido salvo em: {geojson_out}")

    # Matriz W de vizinhança espacial (k=6)
    n = len(linhas)
    coords = [(r['centroide_lon'], r['centroide_lat']) for r in linhas]
    k = 6
    W = [[0.0] * n for _ in range(n)]
    for i in range(n):
        dists = []
        x0, y0 = coords[i]
        for j in range(n):
            if i == j:
                continue
            x1, y1 = coords[j]
            d = math.sqrt((x1 - x0)**2 + (y1 - y0)**2)
            dists.append((d, j))
        dists.sort(key=lambda t: t[0])
        for _, j in dists[:k]:
            W[i][j] = 1.0 / k

    w_out = 'eleicao/data/processed/matriz_W_knn6.csv'
    with open(w_out, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        for row in W:
            writer.writerow(row)
    print(f"5. Matriz W espacial salva em: {w_out}")
    print("Processamento concluído com sucesso!")

if __name__ == '__main__':
    main()
