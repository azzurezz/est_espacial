#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script: prepara_dados.py
Descrição: Processa e unifica os dados de votação do TSE (2026 - Governador MG),
           dados de Soja do IBGE (PAM 5457), PIB municipal e agropecuário (IBGE 5938),
           geometrias e centroides dos 853 municípios de Minas Gerais.
"""

import json
import csv
import unicodedata
import os
import math

def clean_str(s):
    if not s:
        return ""
    s = unicodedata.normalize('NFD', s)
    return ''.join(c for c in s if unicodedata.category(c) != 'Mn').strip().upper()

def calcular_centroide_e_bbox(geometry):
    """Calcula o centroide exato (lon, lat) e bbox a partir de Polygon ou MultiPolygon"""
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
        c_lon = cx_num / total_area
        c_lat = cy_num / total_area
    else:
        c_lon = sum(all_lons) / len(all_lons)
        c_lat = sum(all_lats) / len(all_lats)
        
    return c_lon, c_lat, (min(all_lons), min(all_lats), max(all_lons), max(all_lats))

def main():
    print("Iniciando unificação de dados...")
    
    # 1. Carregar municípios IBGE
    with open('eleicao/data/raw/ibge_mg_municipios.json', encoding='utf-8') as f:
        ibge_list = json.load(f)
        
    ibge_map = {}
    for m in ibge_list:
        clean_name = clean_str(m['nome'])
        ibge_map[clean_name] = {
            'cod_ibge': str(m['id']),
            'nome_ibge': m['nome'],
            'mesorregiao': m['microrregiao']['mesorregiao']['nome'],
            'microrregiao': m['microrregiao']['nome']
        }
    print(f"1. Mapeados {len(ibge_map)} municípios do IBGE.")
    
    # 2. Carregar Soja (PAM Tabela 5457)
    with open('eleicao/data/raw/ibge_soja_mg.json', encoding='utf-8') as f:
        soja_raw = json.load(f)
        
    soja_data = {}
    for row in soja_raw[1:]:
        cod = row['D1C']
        var = row['D2C']
        val_str = row['V']
        val = float(val_str) if val_str not in ['...', '-', '..', 'X'] else 0.0
        if cod not in soja_data:
            soja_data[cod] = {'soja_area_colhida_ha': 0.0, 'soja_producao_ton': 0.0, 'soja_valor_mil_reais': 0.0}
        if var == '216':
            soja_data[cod]['soja_area_colhida_ha'] = val
        elif var == '214':
            soja_data[cod]['soja_producao_ton'] = val
        elif var == '215':
            soja_data[cod]['soja_valor_mil_reais'] = val
    print(f"2. Dados de soja processados para {len(soja_data)} municípios.")
    
    # 3. Carregar PIB / Agropecuária (Tabela 5938)
    with open('eleicao/data/raw/ibge_pib_agro_mg.json', encoding='utf-8') as f:
        pib_raw = json.load(f)
        
    pib_data = {}
    for row in pib_raw[1:]:
        cod = row['D1C']
        var = row['D2C']
        val_str = row['V']
        val = float(val_str) if val_str not in ['...', '-', '..', 'X'] else 0.0
        if cod not in pib_data:
            pib_data[cod] = {'pib_total_mil': 0.0, 'pib_agro_mil': 0.0, 'share_agro_pct': 0.0}
        if var == '37':
            pib_data[cod]['pib_total_mil'] = val
        elif var == '513':
            pib_data[cod]['pib_agro_mil'] = val
        elif var == '516':
            pib_data[cod]['share_agro_pct'] = val
    print(f"3. Dados de PIB/Agro processados para {len(pib_data)} municípios.")
    
    # 4. Processar Votação Governador 2026 MG (TSE)
    tse_votos = {}
    with open('eleicao/data/raw/votacao_candidato_munzona_2026_MG.csv', encoding='latin1') as f:
        reader = csv.DictReader(f, delimiter=';')
        for row in reader:
            if row['DS_CARGO'] != 'Governador':
                continue
            nm_mun = clean_str(row['NM_MUNICIPIO'])
            votos = int(row['QT_VOTOS_NOMINAIS_VALIDOS'])
            cand_num = row['NR_CANDIDATO']
            
            if nm_mun not in tse_votos:
                tse_votos[nm_mun] = {
                    'votos_validos_total': 0,
                    'votos_flavio_roscoe': 0,
                    'votos_cleitinho': 0,
                    'votos_kalil': 0,
                    'votos_patrus': 0,
                    'votos_simoes': 0
                }
            tse_votos[nm_mun]['votos_validos_total'] += votos
            if cand_num == '22':
                tse_votos[nm_mun]['votos_flavio_roscoe'] += votos
            elif cand_num == '10':
                tse_votos[nm_mun]['votos_cleitinho'] += votos
            elif cand_num == '12':
                tse_votos[nm_mun]['votos_kalil'] += votos
            elif cand_num == '13':
                tse_votos[nm_mun]['votos_patrus'] += votos
            elif cand_num == '55':
                tse_votos[nm_mun]['votos_simoes'] += votos
    print(f"4. Votação apurada para {len(tse_votos)} municípios.")
    
    # 5. Carregar GeoJSON e extrair centroides
    with open('eleicao/data/raw/mg_municipios.geojson', encoding='utf-8') as f:
        geojson_data = json.load(f)
        
    centroides = {}
    for feat in geojson_data['features']:
        cod = feat['properties']['codarea']
        c_lon, c_lat, bbox = calcular_centroide_e_bbox(feat['geometry'])
        centroides[cod] = {
            'lon': round(c_lon, 5),
            'lat': round(c_lat, 5),
            'bbox': bbox
        }
        
    # 6. Unificar base tabular
    linhas_finais = []
    for nm_clean, info_ibge in ibge_map.items():
        cod_ibge = info_ibge['cod_ibge']
        soja = soja_data.get(cod_ibge, {'soja_area_colhida_ha': 0.0, 'soja_producao_ton': 0.0, 'soja_valor_mil_reais': 0.0})
        pib = pib_data.get(cod_ibge, {'pib_total_mil': 0.0, 'pib_agro_mil': 0.0, 'share_agro_pct': 0.0})
        voto = tse_votos.get(nm_clean, {
            'votos_validos_total': 0, 'votos_flavio_roscoe': 0,
            'votos_cleitinho': 0, 'votos_kalil': 0, 'votos_patrus': 0, 'votos_simoes': 0
        })
        cent = centroides.get(cod_ibge, {'lon': 0.0, 'lat': 0.0})
        
        tot_val = voto['votos_validos_total']
        pct_flavio = (voto['votos_flavio_roscoe'] / tot_val * 100.0) if tot_val > 0 else 0.0
        pct_cleitinho = (voto['votos_cleitinho'] / tot_val * 100.0) if tot_val > 0 else 0.0
        pct_kalil = (voto['votos_kalil'] / tot_val * 100.0) if tot_val > 0 else 0.0
        pct_patrus = (voto['votos_patrus'] / tot_val * 100.0) if tot_val > 0 else 0.0
        pct_simoes = (voto['votos_simoes'] / tot_val * 100.0) if tot_val > 0 else 0.0
        
        linhas_finais.append({
            'cod_ibge': cod_ibge,
            'municipio': info_ibge['nome_ibge'],
            'mesorregiao': info_ibge['mesorregiao'],
            'microrregiao': info_ibge['microrregiao'],
            'centroide_lon': cent['lon'],
            'centroide_lat': cent['lat'],
            'votos_validos_total': tot_val,
            'votos_flavio_roscoe': voto['votos_flavio_roscoe'],
            'pct_votos_flavio': round(pct_flavio, 3),
            'pct_votos_cleitinho': round(pct_cleitinho, 3),
            'pct_votos_kalil': round(pct_kalil, 3),
            'pct_votos_patrus': round(pct_patrus, 3),
            'pct_votos_simoes': round(pct_simoes, 3),
            'soja_area_colhida_ha': round(soja['soja_area_colhida_ha'], 1),
            'soja_producao_ton': round(soja['soja_producao_ton'], 1),
            'soja_valor_mil_reais': round(soja['soja_valor_mil_reais'], 1),
            'tem_soja': 1 if soja['soja_producao_ton'] > 0 else 0,
            'pib_total_mil': round(pib['pib_total_mil'], 1),
            'pib_agro_mil': round(pib['pib_agro_mil'], 1),
            'share_agro_pct': round(pib['share_agro_pct'], 2)
        })
        
    linhas_finais.sort(key=lambda x: x['cod_ibge'])
    
    # Salvar CSV processado
    os.makedirs('eleicao/data/processed', exist_ok=True)
    csv_path = 'eleicao/data/processed/dados_eleicao_soja_mg.csv'
    with open(csv_path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=list(linhas_finais[0].keys()))
        writer.writeheader()
        writer.writerows(linhas_finais)
    print(f"5. Arquivo CSV final salvo com sucesso em: {csv_path} ({len(linhas_finais)} municípios)")
    
    # 7. Criar GeoJSON enriquecido com propriedades
    tabela_lookup = {row['cod_ibge']: row for row in linhas_finais}
    for feat in geojson_data['features']:
        cod = feat['properties']['codarea']
        if cod in tabela_lookup:
            row = tabela_lookup[cod]
            feat['properties'] = {
                'cod_ibge': cod,
                'municipio': row['municipio'],
                'mesorregiao': row['mesorregiao'],
                'pct_votos_flavio': row['pct_votos_flavio'],
                'votos_flavio': row['votos_flavio_roscoe'],
                'votos_validos': row['votos_validos_total'],
                'soja_producao_ton': row['soja_producao_ton'],
                'soja_area_ha': row['soja_area_colhida_ha'],
                'tem_soja': row['tem_soja'],
                'share_agro_pct': row['share_agro_pct'],
                'pib_agro_mil': row['pib_agro_mil'],
                'pib_total_mil': row['pib_total_mil'],
                'lon': row['centroide_lon'],
                'lat': row['centroide_lat']
            }
            
    geojson_path = 'eleicao/data/processed/mg_municipios_completo.geojson'
    with open(geojson_path, 'w', encoding='utf-8') as f:
        json.dump(geojson_data, f, ensure_ascii=False)
    print(f"6. GeoJSON completo enriquecido salvo em: {geojson_path}")
    
    # 8. Construir Matriz de Vizinhança Espacial W (k-vizinhos mais próximos, k=6)
    n = len(linhas_finais)
    coords = [(row['centroide_lon'], row['centroide_lat']) for row in linhas_finais]
    
    k = 6
    W = [[0.0] * n for _ in range(n)]
    for i in range(n):
        dists = []
        x0, y0 = coords[i]
        for j in range(n):
            if i == j:
                continue
            x1, y1 = coords[j]
            # Distância euclidiana em graus (para k-NN local em MG funciona perfeitamente)
            d = math.sqrt((x1 - x0)**2 + (y1 - y0)**2)
            dists.append((d, j))
        dists.sort(key=lambda t: t[0])
        for _, j in dists[:k]:
            W[i][j] = 1.0 / k  # Padronização por linha
            
    w_path = 'eleicao/data/processed/matriz_W_knn6.csv'
    with open(w_path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        for row in W:
            writer.writerow(row)
    print(f"7. Matriz de Pesos Espaciais W (k=6) salva em: {w_path}")
    print("Processamento concluído com sucesso!")

if __name__ == '__main__':
    main()
