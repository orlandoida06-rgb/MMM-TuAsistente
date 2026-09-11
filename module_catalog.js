'use strict';

const fs = require('fs');
const path = require('path');

const DEFAULT_ALIASES = {
  'MMM-TuAsistente': [
    'tuasistente',
    'tu asistente',
    'asistente'
  ],

  'MMM-TuAsistente-Spotify': [
    'spotify',
    'música',
    'musica'
  ],

  'MMM-WeatherHero': [
    'weatherhero',
    'weather hero',
    'tiempo',
    'clima'
  ]
};

function normalize(text) {
  return String(text || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[¡!¿?.,;:]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function displayName(moduleName) {
  return moduleName
    .replace(/^MMM-/i, '')
    .replace(/[-_]+/g, ' ')
    .trim();
}

function getAliases(moduleName) {
  const aliases = DEFAULT_ALIASES[moduleName] || [];

  const generated = [
    moduleName,
    displayName(moduleName)
  ];

  return [...new Set(
    [...aliases, ...generated]
      .map(normalize)
      .filter(Boolean)
  )];
}

function getModules(modulesDir) {
  const modules = [];

  if (!fs.existsSync(modulesDir)) {
    return modules;
  }

  const entries = fs.readdirSync(modulesDir, {
    withFileTypes: true
  });

  for (const entry of entries) {
    if (!entry.isDirectory()) continue;

    const moduleName = entry.name;

    if (
      moduleName === 'MMM-TuAsistente-test' ||
      moduleName.startsWith('MMM-TuAsistente_backup_')
    ) {
      continue;
    }

    const moduleDir = path.join(modulesDir, moduleName);

    if (!fs.existsSync(path.join(moduleDir, '.git'))) {
      continue;
    }

    modules.push({
      name: moduleName,
      displayName: displayName(moduleName),
      path: moduleDir,
      aliases: getAliases(moduleName)
    });
  }

  return modules;
}

function findModule(target, modulesDir) {
  const normalizedTarget = normalize(target);

  if (!normalizedTarget) {
    return null;
  }

  const modules = getModules(modulesDir);

  for (const module of modules) {
    if (module.aliases.includes(normalizedTarget)) {
      return module;
    }
  }

  for (const module of modules) {
    if (
      normalize(module.name).includes(normalizedTarget) ||
      normalizedTarget.includes(normalize(module.name))
    ) {
      return module;
    }
  }

  for (const module of modules) {
    if (
      normalize(module.displayName).includes(normalizedTarget) ||
      normalizedTarget.includes(normalize(module.displayName))
    ) {
      return module;
    }
  }

  return null;
}

module.exports = {
  normalize,
  getModules,
  findModule
};
