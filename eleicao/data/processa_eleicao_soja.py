#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script: processa_eleicao_soja.py
Objetivo: 
  - Processa os dados de Soja da Tabela 1612 fornecida pelo usuário (soja_mg_municipios.csv).
  - Extrai os votos oficiais para PRESIDENTE (1º Turno - 04/10/2026) em Minas Gerais
    para Flávio Nantes Bolsonaro (PL - 22), Lula (PT - 13) e demais candidatos.
  - Unifica por código e nome dos 853 municípios de Minas Gerais.
  - Constrói a base tratada, GeoJSON enriquecido e Matriz W de vizinhança espacial.
"""

import zipfile
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
    print("Iniciando processamento com dados de Presidente (1º Turno) e Soja...")

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

    # 2. Carregar arquivo soja_mg_municipios.csv (fornecido pelo usuário)
    soja_map = {}
    with open('eleicao/soja_mg_municipios.csv', encoding='utf-8-sig') as f:
        reader = csv.reader(f, delimiter=';')
        for row in reader:
            if not row or len(row) < 2:
                continue
            col0 = row[0].strip().replace('"', '')
            val_str = row[1].strip().replace('"', '')
            if col0.endswith('(MG)'):
                mun_nome = col0[:-4].strip()
                mun_clean = clean_str(mun_nome)
                if val_str in ['-', '...', '..', '', 'X']:
                    area_ha = 0.0
                else:
                    try:
                        area_ha = float(val_str.replace(',', '.'))
                    except ValueError:
                        area_ha = 0.0
                soja_map[mun_clean] = area_ha

    print(f"2. Dados de soja lidos para {len(soja_map)} municípios.")
    mun_com_soja = sum(1 for v in soja_map.values() if v > 0)
    print(f"   Municípios com cultivo de soja (> 0 ha): {mun_com_soja}")

    # 3. Carregar PIB e Agropecuária municipal (IBGE 5938)
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
    print(f"3. Dados econômicos de PIB/Agro vinculados.")

    # 4. Extrair votação de PRESIDENTE 1º TURNO (04/10/2026) em MG
    votos_mun = {}
    zip_path = 'eleicao/votacao_secao_2026_BR.zip'
    
    print("4. Lendo votos de Presidente no 1º Turno (04/10/2026) do TSE...")
    with zipfile.ZipFile(zip_path) as z:
        with z.open('votacao_secao_2026_BR.csv') as f:
            header = [h.replace('"', '').strip() for h in f.readline().decode('latin1').split(';')]
            idx_uf = header.index('SG_UF')
            idx_cargo = header.index('DS_CARGO')
            idx_turno = header.index('NR_TURNO')
            idx_mun = header.index('NM_MUNICIPIO')
            idx_cd_mun = header.index('CD_MUNICIPIO')
            idx_cand = header.index('NR_VOTAVEL')
            idx_votos = header.index('QT_VOTOS')

            for line in f:
                parts = [p.replace('"', '').strip() for p in line.decode('latin1').split(';')]
                if len(parts) <= idx_votos:
                    continue
                if parts[idx_uf] == 'MG' and parts[idx_cargo] == 'Presidente' and parts[idx_turno] == '1':
                    mun_clean = clean_str(parts[idx_mun])
                    cand = parts[idx_cand]
                    votos = int(parts[idx_votos])

                    if mun_clean not in votos_mun:
                        votos_mun[mun_clean] = {
                            'total_validos': 0,
                            'flavio_bolsonaro': 0,
                            'lula': 0,
                            'caiado': 0,
                            'zema': 0,
                            'outros': 0,
                            'brancos': 0,
                            'nulos': 0
                        }

                    if cand == '95':
                        votos_mun[mun_clean]['brancos'] += votos
                    elif cand == '96':
                        votos_mun[mun_clean]['nulos'] += votos
                    else:
                        votos_mun[mun_clean]['total_validos'] += votos
                        if cand == '22':
                            votos_mun[mun_clean]['flavio_bolsonaro'] += votos
                        elif cand == '13':
                            votos_mun[mun_clean]['lula'] += votos
                        elif cand == '55':
                            votos_mun[mun_clean]['caiado'] += votos
                        elif cand == '30':
                            votos_mun[mun_clean]['zema'] += votos
                        else:
                            votos_mun[mun_clean]['outros'] += votos

    print(f"4. Votação de Presidente processada para {len(votos_mun)} municípios em MG.")

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
    tot_flavio_mg = 0
    tot_lula_mg = 0
    tot_validos_mg = 0

    for mun_clean, info_ibge in ibge_map.items():
        cod_ibge = info_ibge['cod_ibge']
        soja_area = soja_map.get(mun_clean, 0.0)
        pib = pib_data.get(cod_ibge, {'pib_total_mil': 0.0, 'pib_agro_mil': 0.0, 'share_agro_pct': 0.0})
        voto = votos_mun.get(mun_clean, {
            'total_validos': 0, 'flavio_bolsonaro': 0, 'lula': 0, 'caiado': 0, 'zema': 0
        })
        cent = centroides.get(cod_ibge, {'lon': 0.0, 'lat': 0.0})

        tot_val = voto['total_validos']
        v_flavio = voto['flavio_bolsonaro']
        v_lula = voto['lula']

        tot_validos_mg += tot_val
        tot_flavio_mg += v_flavio
        tot_lula_mg += v_lula

        pct_flavio = (v_flavio / tot_val * 100.0) if tot_val > 0 else 0.0
        pct_lula = (v_lula / tot_val * 100.0) if tot_val > 0 else 0.0
        pct_caiado = (voto['caiado'] / tot_val * 100.0) if tot_val > 0 else 0.0
        pct_zema = (voto['zema'] / tot_val * 100.0) if tot_val > 0 else 0.0

        linhas.append({
            'cod_ibge': cod_ibge,
            'municipio': info_ibge['nome_ibge'],
            'mesorregiao': info_ibge['mesorregiao'],
            'microrregiao': info_ibge['microrregiao'],
            'centroide_lon': cent['lon'],
            'centroide_lat': cent['lat'],
            'votos_validos_total': tot_val,
            'votos_flavio_bolsonaro': v_flavio,
            'pct_votos_flavio_bolsonaro': round(pct_flavio, 3),
            'votos_lula': v_lula,
            'pct_votos_lula': round(pct_lula, 3),
            'pct_votos_caiado': round(pct_caiado, 3),
            'pct_votos_zema': round(pct_zema, 3),
            'soja_area_plantada_ha': round(soja_area, 1),
            'tem_soja': 1 if soja_area > 0 else 0,
            'pib_total_mil': round(pib['pib_total_mil'], 1),
            'pib_agro_mil': round(pib['pib_agro_mil'], 1),
            'share_agro_pct': round(pib['share_agro_pct'], 2)
        })

    linhas.sort(key=lambda x: x['cod_ibge'])

    print(f"\n--- TOTAIS ESTADUAIS DE MINAS GERAIS (1º TURNO 2026 - PRESIDENTE) ---")
    print(f"Total Votos Válidos: {tot_validos_mg:,}")
    print(f"Flávio Bolsonaro: {tot_flavio_mg:,} votos ({tot_flavio_mg / tot_validos_mg * 100:.2f}%)")
    print(f"Luiz Inácio Lula da Silva: {tot_lula_mg:,} votos ({tot_lula_mg / tot_validos_mg * 100:.2f}%)")

    # Salvar CSV final processado
    csv_out = 'eleicao/data/processed/dados_eleicao_soja_mg.csv'
    with open(csv_out, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=list(linhas[0].keys()))
        writer.writeheader()
        writer.writerows(linhas)
    print(f"5. Base final de dados salva em: {csv_out}")

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
                'tem_soja': r['tem_soja'],
                'share_agro_pct': r['share_agro_pct'],
                'pib_total_mil': r['pib_total_mil']
            }
    geojson_out = 'eleicao/data/processed/mg_municipios_completo.geojson'
    with open(geojson_out, 'w', encoding='utf-8') as f:
        json.dump(geojson_data, f, ensure_ascii=False)
    print(f"6. GeoJSON atualizado em: {geojson_out}")

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
    print(f"7. Matriz W espacial salva em: {w_out}")

    # 7. Salvar extrato municipal da votação de Presidente em MG para arquivo local
    # substituindo o conteúdo não necessário
    print("Processamento concluído com sucesso!")

if __name__ == '__main__':
    main()
